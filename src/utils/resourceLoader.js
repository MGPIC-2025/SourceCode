const RETRY_CONFIG = {
  maxRetries: 3,
  retryDelay: 1000,
  timeout: 10000,
};
const resourceCache = new Map();
let assetListCache = null;
const PRECACHE_CONFIG = {
  enabled: true,
  maxCacheSize: 50 * 1024 * 1024,
  cachePrefix: 'mgpic_',
  version: '1.0.0',
  loadInterval: 50,
  batchSize: 3,
};
class LocalCacheManager {
  constructor() {
    this.cache = new Map();
    this.totalSize = 0;
  }
  isSupported() {
    return 'caches' in window;
  }
  getCacheName() {
    return `${PRECACHE_CONFIG.cachePrefix}${PRECACHE_CONFIG.version}`;
  }
  async isCached(url) {
    if (!this.isSupported()) return false;
    try {
      const cache = await caches.open(this.getCacheName());
      const response = await cache.match(url);
      return response !== undefined;
    } catch (error) {
      return false;
    }
  }
  async cacheResource(url, response) {
    if (!this.isSupported()) return false;
    try {
      const cache = await caches.open(this.getCacheName());
      const existing = await cache.match(url);
      if (existing) {
        return true;
      }
      await cache.put(url, response.clone());
      const contentLength = response.headers.get('content-length');
      if (contentLength) {
        this.totalSize += parseInt(contentLength);
      }
      return true;
    } catch (error) {
      return false;
    }
  }
  async getCachedResource(url) {
    if (!this.isSupported()) return null;
    try {
      const cache = await caches.open(this.getCacheName());
      return await cache.match(url);
    } catch (error) {
      return null;
    }
  }
  async cleanupCache() {
    if (!this.isSupported()) return;
    try {
      const cacheNames = await caches.keys();
      const currentCacheName = this.getCacheName();
      for (const cacheName of cacheNames) {
        if (
          cacheName.startsWith(PRECACHE_CONFIG.cachePrefix) &&
          cacheName !== currentCacheName
        ) {
          await caches.delete(cacheName);
        }
      }
    } catch (error) {
    }
  }
}
const cacheManager = new LocalCacheManager();
let cachedBaseUrl = null;
function getResourceBaseUrl() {
  if (cachedBaseUrl) {
    return cachedBaseUrl;
  }
  const customDomain = import.meta.env.VITE_R2_CUSTOM_DOMAIN;
  const publicUrl = import.meta.env.VITE_R2_PUBLIC_URL;
  if (customDomain) {
    cachedBaseUrl = customDomain;
    return cachedBaseUrl;
  } else {
    cachedBaseUrl = 'https://pub-6f9181bda40946ea92b5e87fe84e27d4.r2.dev';
    return cachedBaseUrl;
  }
}
export function getAssetUrl(path) {
  let clean_path = path;
  if (path.startsWith('/assets/')) {
    clean_path = path.slice(7);
  } else if (path.startsWith('@assets/')) {
    clean_path = path.slice(8);
  }
  const baseUrl = getResourceBaseUrl();
  const cleanPath = clean_path.startsWith('/')
    ? clean_path.slice(1)
    : clean_path;
  const fullUrl = `${baseUrl}/${cleanPath}`;
  return fullUrl;
}
async function loadResourceWithRetry(url, options = {}) {
  const {
    maxRetries = RETRY_CONFIG.maxRetries,
    retryDelay = RETRY_CONFIG.retryDelay,
  } = options;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(
        () => controller.abort(),
        RETRY_CONFIG.timeout
      );
      const response = await fetch(url, {
        method: 'HEAD',
        mode: 'cors',
        credentials: 'omit',
        cache: 'no-cache',
        signal: controller.signal,
        ...options,
      });
      clearTimeout(timeoutId);
      if (response.ok) {
        resourceCache.set(url, { success: true, timestamp: Date.now() });
        return response;
      } else {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
    } catch (error) {
      if (attempt === maxRetries) {
        resourceCache.set(url, {
          success: false,
          timestamp: Date.now(),
          error: error.message,
        });
        throw error;
      }
      await new Promise(resolve => setTimeout(resolve, retryDelay * attempt));
    }
  }
}
export async function loadResourceWithCache(url, options = {}) {
  if (cacheManager.isSupported()) {
    const cachedResponse = await cacheManager.getCachedResource(url);
    if (cachedResponse) {
      return cachedResponse;
    }
  }
  const {
    maxRetries = RETRY_CONFIG.maxRetries,
    retryDelay = RETRY_CONFIG.retryDelay,
  } = options;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(
        () => controller.abort(),
        RETRY_CONFIG.timeout
      );
      const response = await fetch(url, {
        method: 'GET',
        mode: 'cors',
        credentials: 'omit',
        cache: 'no-cache',
        signal: controller.signal,
        ...options,
      });
      clearTimeout(timeoutId);
      if (response.ok) {
        if (cacheManager.isSupported()) {
          await cacheManager.cacheResource(url, response);
        }
        return response;
      } else {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
    } catch (error) {
      if (attempt === maxRetries) {
        throw error;
      }
      const waitTime = retryDelay * attempt;
      await new Promise(resolve => setTimeout(resolve, waitTime));
    }
  }
}
async function checkResourceAvailability(url) {
  if (resourceCache.has(url)) {
    const cached = resourceCache.get(url);
    const now = Date.now();
    if (now - cached.timestamp < 5 * 60 * 1000) {
      return cached.success;
    }
  }
  try {
    await loadResourceWithRetry(url);
    return true;
  } catch (error) {
    return false;
  }
}
export async function preloadAssets(paths) {
  const promises = paths.map(async path => {
    const url = getAssetUrl(path);
    try {
      if (path.endsWith('.glb')) {
        await loadResourceWithRetry(url);
      } else if (path.match(/\.(webp|png|jpg|jpeg)$/)) {
        await loadResourceWithRetry(url);
      } else {
        await loadResourceWithRetry(url);
      }
    } catch (error) {
    }
  });
  try {
    await Promise.all(promises);
  } catch (error) {
  }
}
async function loadAssetList(priorities = ['high', 'medium']) {
  try {
    if (assetListCache) {
      const resources = extractResourcesFromAssetList(
        assetListCache,
        priorities
      );
      return resources;
    }
    const assetListUrl = getAssetUrl('asset-list.json');
    const response = await loadResourceWithCache(assetListUrl);
    if (!response.ok) {
      throw new Error(`资源列表加载失败: HTTP ${response.status}`);
    }
    const assetList = await response.json();
    assetListCache = assetList;
    const resources = extractResourcesFromAssetList(assetList, priorities);
    return resources;
  } catch (error) {
    return [
      'logo.glb',
      'frontend_resource/start_game.webp',
      'frontend_resource/copper_warehouse.webp',
      'frontend_resource/game_wiki.webp',
      'frontend_resource/Tutorial.webp',
      'frontend_resource/gacha.webp',
    ];
  }
}
function extractResourcesFromAssetList(assetList, priorities) {
  const resources = [];
  for (const priority of priorities) {
    if (assetList.categories && assetList.categories[priority]) {
      const categoryResources = assetList.categories[priority].resources || [];
      resources.push(...categoryResources.map(r => r.path));
    }
  }
  return resources;
}
export async function precacheAllResources(
  onProgress = null,
  priorities = ['high', 'medium']
) {
  if (!PRECACHE_CONFIG.enabled) {
    return;
  }
  await cacheManager.cleanupCache();
  const allResources = await loadAssetList(priorities);
  const batchSize = PRECACHE_CONFIG.batchSize;
  const loadInterval = PRECACHE_CONFIG.loadInterval;
  const totalResources = allResources.length;
  let loadedCount = 0;
  if (onProgress) {
    onProgress(0, totalResources, 0);
  }
  for (let i = 0; i < allResources.length; i += batchSize) {
    const batch = allResources.slice(i, i + batchSize);
    const batchPromises = batch.map(async (path, index) => {
      const url = getAssetUrl(path);
      try {
        const isCached = await cacheManager.isCached(url);
        if (isCached) {
          return { success: true, path, cached: true, source: 'cache' };
        }
        const controller = new AbortController();
        const timeoutId = setTimeout(
          () => controller.abort(),
          RETRY_CONFIG.timeout
        );
        const response = await fetch(url, {
          method: 'GET',
          mode: 'cors',
          credentials: 'omit',
          cache: 'no-cache',
          signal: controller.signal,
        });
        clearTimeout(timeoutId);
        if (response.ok) {
          const fromCache =
            response.headers.get('x-cache') ||
            response.headers.get('cf-cache-status') ||
            (response.type === 'basic' && !response.redirected);
          if (cacheManager.isSupported()) {
            await cacheManager.cacheResource(url, response);
          }
          return {
            success: true,
            path,
            cached: false,
            fromBrowserCache: !!fromCache,
          };
        } else {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
      } catch (error) {
        return { success: false, path, error: error.message };
      }
    });
    const results = await Promise.all(batchPromises);
    loadedCount += batch.length;
    const percentage = Math.round((loadedCount / totalResources) * 100);
    if (onProgress) {
      onProgress(loadedCount, totalResources, percentage);
    }
    const successCount = results.filter(r => r.success).length;
    const cachedCount = results.filter(r => r.cached).length;
    const browserCacheCount = results.filter(r => r.fromBrowserCache).length;
    const errorCount = results.filter(r => !r.success).length;
    if (i + batchSize < allResources.length) {
      await new Promise(resolve => setTimeout(resolve, loadInterval));
    }
  }
  if (onProgress) {
    onProgress(totalResources, totalResources, 100);
  }
}
export async function getCacheStatus() {
  if (!cacheManager.isSupported()) {
    return { supported: false, message: '浏览器不支持缓存API' };
  }
  try {
    const cache = await caches.open(cacheManager.getCacheName());
    const keys = await cache.keys();
    return {
      supported: true,
      cacheName: cacheManager.getCacheName(),
      resourceCount: keys.length,
      totalSize: cacheManager.totalSize,
      maxSize: PRECACHE_CONFIG.maxCacheSize,
    };
  } catch (error) {
    return { supported: true, error: error.message };
  }
}
export function updatePrecacheConfig(config) {
  if (config.loadInterval !== undefined) {
    PRECACHE_CONFIG.loadInterval = Math.max(100, config.loadInterval);
  }
  if (config.batchSize !== undefined) {
    PRECACHE_CONFIG.batchSize = Math.max(1, Math.min(10, config.batchSize));
  }
  if (config.enabled !== undefined) {
    PRECACHE_CONFIG.enabled = config.enabled;
  }
}
export function getPrecacheConfig() {
  return { ...PRECACHE_CONFIG };
}
export function clearAssetListCache() {
  assetListCache = null;
}
export function getCopperModelUrl(copperType, copperName) {
  return getAssetUrl(
    `copper/${copperType.toLowerCase()}/${copperName}/${copperName}.glb`
  );
}
export function getCopperIconUrl(copperType, copperName) {
  return getAssetUrl(
    `copper/${copperType.toLowerCase()}/${copperName}/${copperName}.webp`
  );
}
export function getEnemyModelUrl(enemyName) {
  return getAssetUrl(`enemy/${enemyName}/${enemyName}.glb`);
}
export function getStructureModelUrl(structureName) {
  return getAssetUrl(`structure/${structureName}/${structureName}.glb`);
}
export function getResourceModelUrl(resourceName) {
  return getAssetUrl(`resource/${resourceName}/${resourceName}.glb`);
}
export function getMaterialModelUrl(modelUrl) {
  return getAssetUrl(modelUrl);
}
export function getEquipmentIconUrl(equipmentName) {
  return getAssetUrl(`equipment/${equipmentName}.webp`);
}
export async function loadImageWithRetry(path) {
  const url = getAssetUrl(path);
  try {
    const isAvailable = await checkResourceAvailability(url);
    if (isAvailable) {
      return url;
    } else {
      throw new Error('Resource not available');
    }
  } catch (error) {
    return url;
  }
}
export async function loadModelWithRetry(path) {
  const url = getAssetUrl(path);
  try {
    const isAvailable = await checkResourceAvailability(url);
    if (isAvailable) {
      return url;
    } else {
      throw new Error('Resource not available');
    }
  } catch (error) {
    return url;
  }
}