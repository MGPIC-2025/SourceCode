import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';
import { loadResourceWithCache } from './resourceLoader.js';
class ModelCacheManager {
  constructor() {
    this.gltfCache = new Map();
    this.modelPool = new Map();
    this.instancedMeshes = new Map();
    this.gltfLoader = null;
    this.dracoLoader = null;
    this.maxCacheSize = 50;
    this.maxInstancesPerModel = 1000;
    this.preloadStatus = new Map();
    this.preloadQueue = [];
    this.initLoaders();
  }
  initLoaders() {
    if (!this.gltfLoader) {
      this.gltfLoader = new GLTFLoader();
      this.gltfLoader.setCrossOrigin('anonymous');
      this.dracoLoader = new DRACOLoader();
      this.dracoLoader.setDecoderPath(
        'https://www.gstatic.com/draco/versioned/decoders/1.5.6/'
      );
      this.dracoLoader.setCrossOrigin('anonymous');
      this.gltfLoader.setDRACOLoader(this.dracoLoader);
    }
  }
  async loadModel(url, useInstancePool = true) {
    if (useInstancePool && this.modelPool.has(url)) {
      const poolInstance = this.modelPool.get(url);
      return poolInstance.clone(true);
    }
    let gltf;
    if (this.gltfCache.has(url)) {
      gltf = this.gltfCache.get(url);
    } else {
      try {
        const response = await loadResourceWithCache(url);
        const arrayBuffer = await response.arrayBuffer();
        gltf = await new Promise((resolve, reject) => {
          this.gltfLoader.parse(
            arrayBuffer,
            '',
            parsed => resolve(parsed),
            error => reject(error)
          );
        });
        this.cacheGLTF(url, gltf);
      } catch (error) {
        throw error;
      }
    }
    const instance = gltf.scene.clone(true);
    if (useInstancePool) {
      this.addToModelPool(url, instance);
    }
    return instance;
  }
  async createInstancedMesh(url, maxInstances = 100) {
    if (this.instancedMeshes.has(url)) {
      return this.instancedMeshes.get(url);
    }
    const model = await this.loadModel(url, true);
    const meshes = [];
    model.traverse(child => {
      if (child.isMesh) {
        meshes.push(child);
      }
    });
    if (meshes.length === 0) {
      throw new Error(`[ModelCache] 模型中没有网格: ${url}`);
    }
    const templateMesh = meshes[0];
    const instancedMesh = new THREE.InstancedMesh(
      templateMesh.geometry,
      templateMesh.material,
      maxInstances
    );
    const matrix = new THREE.Matrix4();
    for (let i = 0; i < maxInstances; i++) {
      matrix.setPosition(0, -1000, 0);
      instancedMesh.setMatrixAt(i, matrix);
    }
    instancedMesh.instanceMatrix.needsUpdate = true;
    this.instancedMeshes.set(url, instancedMesh);
    return instancedMesh;
  }
  updateInstancedMeshInstance(url, instanceIndex, position, rotation, scale) {
    const instancedMesh = this.instancedMeshes.get(url);
    if (!instancedMesh) {
      return;
    }
    if (instanceIndex >= instancedMesh.count) {
      return;
    }
    const matrix = new THREE.Matrix4();
    matrix.compose(
      position,
      new THREE.Quaternion().setFromEuler(rotation),
      scale
    );
    instancedMesh.setMatrixAt(instanceIndex, matrix);
    instancedMesh.instanceMatrix.needsUpdate = true;
  }
  hideInstancedMeshInstance(url, instanceIndex) {
    const instancedMesh = this.instancedMeshes.get(url);
    if (!instancedMesh) return;
    const matrix = new THREE.Matrix4();
    matrix.setPosition(0, -1000, 0);
    instancedMesh.setMatrixAt(instanceIndex, matrix);
    instancedMesh.instanceMatrix.needsUpdate = true;
  }
  cacheGLTF(url, gltf) {
    if (this.gltfCache.size >= this.maxCacheSize) {
      const firstKey = this.gltfCache.keys().next().value;
      this.gltfCache.delete(firstKey);
    }
    this.gltfCache.set(url, gltf);
  }
  addToModelPool(url, instance) {
    if (this.modelPool.size >= this.maxCacheSize) {
      const firstKey = this.modelPool.keys().next().value;
      const oldInstance = this.modelPool.get(firstKey);
      this.disposeModel(oldInstance);
      this.modelPool.delete(firstKey);
    }
    this.modelPool.set(url, instance);
  }
  async preloadModels(urls, onProgress = null) {
    const total = urls.length;
    let loaded = 0;
    const urlsToLoad = urls.filter(url => {
      const status = this.preloadStatus.get(url);
      return !status || status === 'failed';
    });
    const batchSize = 3;
    for (let i = 0; i < urlsToLoad.length; i += batchSize) {
      const batch = urlsToLoad.slice(i, i + batchSize);
      const promises = batch.map(async url => {
        try {
          this.preloadStatus.set(url, 'loading');
          await this.loadModel(url, true);
          this.preloadStatus.set(url, 'loaded');
          loaded++;
          if (onProgress) {
            onProgress(loaded, total, Math.round((loaded / total) * 100));
          }
        } catch (error) {
          this.preloadStatus.set(url, 'failed');
          loaded++;
          if (onProgress) {
            onProgress(loaded, total, Math.round((loaded / total) * 100));
          }
        }
      });
      await Promise.all(promises);
      if (i + batchSize < urlsToLoad.length) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    }
  }
  isPreloaded(url) {
    const status = this.preloadStatus.get(url);
    return status === 'loaded';
  }
  getPreloadStatus() {
    const stats = {
      total: this.preloadStatus.size,
      loaded: 0,
      loading: 0,
      failed: 0,
    };
    for (const status of this.preloadStatus.values()) {
      stats[status]++;
    }
    return stats;
  }
  disposeModel(model) {
    if (!model) return;
    model.traverse(obj => {
      if (obj.isMesh) {
        if (obj.geometry) {
          obj.geometry.dispose();
        }
        if (obj.material) {
          if (Array.isArray(obj.material)) {
            obj.material.forEach(m => {
              if (m.map) m.map.dispose();
              if (m.dispose) m.dispose();
            });
          } else {
            if (obj.material.map) obj.material.map.dispose();
            if (obj.material.dispose) obj.material.dispose();
          }
        }
      }
    });
  }
  clearCache() {
    this.modelPool.forEach(instance => {
      this.disposeModel(instance);
    });
    this.modelPool.clear();
    this.instancedMeshes.forEach(mesh => {
      this.disposeModel(mesh);
    });
    this.instancedMeshes.clear();
    this.gltfCache.clear();
    this.preloadStatus.clear();
  }
  getCacheStatus() {
    return {
      gltfCacheSize: this.gltfCache.size,
      modelPoolSize: this.modelPool.size,
      instancedMeshesSize: this.instancedMeshes.size,
      preloadStatus: this.getPreloadStatus(),
      maxCacheSize: this.maxCacheSize,
      maxInstancesPerModel: this.maxInstancesPerModel,
      gltfLoaderInitialized: !!this.gltfLoader,
      dracoLoaderInitialized: !!this.dracoLoader,
    };
  }
  updateConfig(config) {
    if (config.maxCacheSize !== undefined) {
      this.maxCacheSize = Math.max(10, config.maxCacheSize);
    }
    if (config.maxInstancesPerModel !== undefined) {
      this.maxInstancesPerModel = Math.max(10, config.maxInstancesPerModel);
    }
  }
}
const modelCache = new ModelCacheManager();
export { modelCache, ModelCacheManager };
export default modelCache;