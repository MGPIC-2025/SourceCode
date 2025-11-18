import * as THREE from 'three';
export function useHealthBars(scene, camera) {
  const healthBars = new Map();
  function createOrUpdateHealthBar(unitId, currentHp, maxHp) {
    if (healthBars.has(unitId)) {
      const barData = healthBars.get(unitId);
      barData.maxHp = maxHp;
      updateHealthBarValue(unitId, currentHp, maxHp);
      return;
    }
    const barWidth = 1.0;
    const barHeight = 0.1;
    const bgGeometry = new THREE.PlaneGeometry(barWidth, barHeight);
    const bgMaterial = new THREE.MeshBasicMaterial({
      color: 0x440000,
      side: THREE.DoubleSide,
      depthTest: false,
      depthWrite: false,
      transparent: false,
      toneMapped: false,
    });
    const background = new THREE.Mesh(bgGeometry, bgMaterial);
    const barGeometry = new THREE.PlaneGeometry(barWidth, barHeight);
    const barMaterial = new THREE.MeshBasicMaterial({
      color: getHealthColor(currentHp, maxHp),
      side: THREE.DoubleSide,
      depthTest: false,
      depthWrite: false,
      transparent: false,
      toneMapped: false,
    });
    const bar = new THREE.Mesh(barGeometry, barMaterial);
    bar.position.z = 0.001;
    const container = new THREE.Group();
    container.add(background);
    container.add(bar);
    container.renderOrder = 999;
    background.renderOrder = 999;
    bar.renderOrder = 1000;
    scene.add(container);
    healthBars.set(unitId, { bar, background, container, maxHp });
    updateHealthBarValue(unitId, currentHp, maxHp);
  }
  function updateHealthBarValue(unitId, currentHp, maxHp) {
    const barData = healthBars.get(unitId);
    if (!barData) return;
    const { bar } = barData;
    const percentage = Math.max(0, Math.min(1, currentHp / maxHp));
    bar.scale.x = percentage;
    bar.position.x = -(1 - percentage) * 0.5;
    bar.material.color.setHex(getHealthColor(currentHp, maxHp));
  }
  function getHealthColor(currentHp, maxHp) {
    const percentage = currentHp / maxHp;
    if (percentage > 0.6) return 0x00ff00;
    if (percentage > 0.3) return 0xffff00;
    return 0xff0000;
  }
  function removeHealthBar(unitId) {
    const barData = healthBars.get(unitId);
    if (!barData) return;
    const { bar, background, container } = barData;
    bar.geometry.dispose();
    bar.material.dispose();
    background.geometry.dispose();
    background.material.dispose();
    scene.remove(container);
    healthBars.delete(unitId);
  }
  function updateHealthBarsPosition(models) {
    healthBars.forEach((barData, unitId) => {
      const model = models.find(m => m.id === unitId);
      if (model && model.object) {
        const { container } = barData;
        const position = model.object.position.clone();
        position.y += 1.5;
        container.position.copy(position);
        container.lookAt(camera.position);
      }
    });
  }
  function dispose() {
    healthBars.forEach((barData, unitId) => {
      removeHealthBar(unitId);
    });
    healthBars.clear();
  }
  return {
    healthBars,
    createOrUpdateHealthBar,
    updateHealthBarValue,
    removeHealthBar,
    updateHealthBarsPosition,
    dispose,
  };
}