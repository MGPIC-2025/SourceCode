import * as THREE from 'three';
import { useEffectPool } from './useEffectPool.js';
import { getResourceName } from '../utils/mappings.js';
export function useEffects(scene) {
  const effectPool = useEffectPool();
  function createAttackEffect(startPosition, targetPosition) {
    const start = new THREE.Vector3(startPosition[0], 0.5, startPosition[1]);
    const target = new THREE.Vector3(targetPosition[0], 0.5, targetPosition[1]);
    const distance = start.distanceTo(target);
    const line = effectPool.getAttackRay(distance);
    const midpoint = new THREE.Vector3()
      .addVectors(start, target)
      .multiplyScalar(0.5);
    line.position.copy(midpoint);
    const direction = new THREE.Vector3().subVectors(target, start).normalize();
    const quaternion = new THREE.Quaternion();
    quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction);
    line.quaternion.copy(quaternion);
    scene.add(line);
    let opacity = 0.9;
    const fadeOut = () => {
      opacity -= 0.05;
      line.material.opacity = opacity;
      if (opacity <= 0) {
        scene.remove(line);
        effectPool.recycleAttackRay(line);
      } else {
        requestAnimationFrame(fadeOut);
      }
    };
    setTimeout(fadeOut, 300);
    const ring = effectPool.getExplosionRing();
    ring.position.set(targetPosition[0], 0.1, targetPosition[1]);
    scene.add(ring);
    let scale = 1;
    let ringOpacity = 0.8;
    const expand = () => {
      scale += 0.1;
      ringOpacity -= 0.08;
      ring.scale.set(scale, scale, 1);
      ring.material.opacity = ringOpacity;
      if (ringOpacity <= 0) {
        scene.remove(ring);
        effectPool.recycleExplosionRing(ring);
      } else {
        requestAnimationFrame(expand);
      }
    };
    expand();
  }
  function createResourceGainEffect(position, resourceChanges) {
    const messages = Object.entries(resourceChanges)
      .filter(([_, amount]) => amount > 0)
      .map(([resourceType, amount]) => `+${amount} ${getResourceName(resourceType)}`);
    if (!messages.length) return;
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    canvas.width = 512;
    canvas.height = 256;
    ctx.fillStyle = 'rgba(0, 0, 0, 0)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.font = 'bold 48px Arial';
    ctx.fillStyle = '#ffff00';
    ctx.strokeStyle = '#000000';
    ctx.lineWidth = 4;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    const lineHeight = 60;
    const startY = canvas.height / 2 - ((messages.length - 1) * lineHeight) / 2;
    messages.forEach((line, i) => {
      const y = startY + i * lineHeight;
      ctx.strokeText(line, canvas.width / 2, y);
      ctx.fillText(line, canvas.width / 2, y);
    });
    const sprite = new THREE.Sprite(new THREE.SpriteMaterial({
      map: new THREE.CanvasTexture(canvas),
      transparent: true,
      opacity: 1.0,
    }));
    sprite.scale.set(2, 1, 1);
    sprite.position.set(position[0], 1.5, position[1]);
    scene.add(sprite);
    let y = 1.5, opacity = 1.0;
    const rise = () => {
      y += 0.02;
      opacity -= 0.01;
      sprite.position.y = y;
      sprite.material.opacity = opacity;
      if (opacity <= 0) {
        scene.remove(sprite);
        sprite.material.map.dispose();
        sprite.material.dispose();
      } else {
        requestAnimationFrame(rise);
      }
    };
    rise();
  }
  function dispose() {
    effectPool.dispose();
  }
  return {
    createAttackEffect,
    createResourceGainEffect,
    dispose,
  };
}