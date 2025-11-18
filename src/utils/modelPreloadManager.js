import modelCache from './modelCache.js';
import { getModelUrlsByPriority } from './modelPreloadConfig.js';
class ModelPreloadManager {
  constructor() {
    this.isPreloading = false;
    this.preloadProgress = 0;
    this.preloadCallbacks = [];
  }
  async startPreload(priorities = ['high', 'medium'], onProgress = null) {
    if (this.isPreloading) {
      return;
    }
    this.isPreloading = true;
    this.preloadProgress = 0;
    try {
      const urls = getModelUrlsByPriority(priorities);
      if (onProgress) {
        this.preloadCallbacks.push(onProgress);
      }
      await modelCache.preloadModels(urls, (loaded, total, percentage) => {
        this.preloadProgress = percentage;
        this.notifyProgress(loaded, total, percentage);
      });
    } catch (error) {
    } finally {
      this.isPreloading = false;
      this.preloadCallbacks = [];
    }
  }
  notifyProgress(loaded, total, percentage) {
    this.preloadCallbacks.forEach(callback => {
      try {
        callback(loaded, total, percentage);
      } catch (error) {
      }
    });
  }
  getStatus() {
    return {
      isPreloading: this.isPreloading,
      progress: this.preloadProgress,
      cacheStatus: modelCache.getCacheStatus(),
    };
  }
  isModelPreloaded(url) {
    return modelCache.isPreloaded(url);
  }
  async preloadModel(url) {
    try {
      await modelCache.loadModel(url, true);
    } catch (error) {
    }
  }
  async preloadModels(urls) {
    const promises = urls.map(url => this.preloadModel(url));
    await Promise.all(promises);
  }
}
const modelPreloadManager = new ModelPreloadManager();
export { modelPreloadManager, ModelPreloadManager };
export default modelPreloadManager;