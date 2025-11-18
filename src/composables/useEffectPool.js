import * as THREE from 'three';
export function useEffectPool() {
  const attackRayPool = {
    geometries: [],
    materials: [],
    meshes: [],
    maxSize: 10,
  };
  const explosionRingPool = {
    geometries: [],
    materials: [],
    meshes: [],
    maxSize: 10,
  };
  function getAttackRay(distance) {
    let cylinder;
    if (attackRayPool.meshes.length > 0) {
      cylinder = attackRayPool.meshes.pop();
      cylinder.geometry.dispose();
      cylinder.geometry = new THREE.CylinderGeometry(0.05, 0.05, distance, 8);
      cylinder.material.opacity = 0.9;
    } else {
      const geometry = new THREE.CylinderGeometry(0.05, 0.05, distance, 8);
      const material = new THREE.MeshBasicMaterial({
        color: 0xff4444,
        transparent: true,
        opacity: 0.9,
        emissive: 0xff4444,
        emissiveIntensity: 0.5,
      });
      cylinder = new THREE.Mesh(geometry, material);
    }
    return cylinder;
  }
  function recycleAttackRay(cylinder) {
    if (attackRayPool.meshes.length < attackRayPool.maxSize) {
      attackRayPool.meshes.push(cylinder);
    } else {
      cylinder.geometry.dispose();
      cylinder.material.dispose();
    }
  }
  function getExplosionRing() {
    let ring;
    if (explosionRingPool.meshes.length > 0) {
      ring = explosionRingPool.meshes.pop();
      ring.scale.set(1, 1, 1);
      ring.material.opacity = 0.8;
    } else {
      const geometry = new THREE.RingGeometry(0.2, 0.4, 32);
      const material = new THREE.MeshBasicMaterial({
        color: 0xff0000,
        side: THREE.DoubleSide,
        transparent: true,
        opacity: 0.8,
        emissive: 0xff0000,
        emissiveIntensity: 0.5,
      });
      ring = new THREE.Mesh(geometry, material);
      ring.rotation.x = -Math.PI / 2;
    }
    return ring;
  }
  function recycleExplosionRing(ring) {
    if (explosionRingPool.meshes.length < explosionRingPool.maxSize) {
      explosionRingPool.meshes.push(ring);
    } else {
      ring.geometry.dispose();
      ring.material.dispose();
    }
  }
  function dispose() {
    attackRayPool.meshes.forEach(mesh => {
      mesh.geometry.dispose();
      mesh.material.dispose();
    });
    attackRayPool.meshes = [];
    attackRayPool.geometries = [];
    attackRayPool.materials = [];
    explosionRingPool.meshes.forEach(mesh => {
      mesh.geometry.dispose();
      mesh.material.dispose();
    });
    explosionRingPool.meshes = [];
    explosionRingPool.geometries = [];
    explosionRingPool.materials = [];
  }
  return {
    getAttackRay,
    recycleAttackRay,
    getExplosionRing,
    recycleExplosionRing,
    dispose,
  };
}