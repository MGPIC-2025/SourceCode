import mitt from 'mitt';
const eventBus = mitt();
export const EventTypes = {
  UPDATE_RESOURCES: 'update:resources',
  RESOURCES_UPDATED: 'resources:updated',
  COPPER_ID_ADDED: 'copper:id:added',
  START_MENU_PAUSE: 'menu:pause',
  START_MENU_RESUME: 'menu:resume',
  START_MENU_STARTED: 'menu:started',
  CONTROL_MODE_CHANGED: 'control:mode:changed',
  GAME_STARTED: 'game:started',
  GAME_ENDED: 'game:ended',
};
export const emitEvent = (type, data) => {
  eventBus.emit(type, data);
};
export const onEvent = (type, handler) => {
  eventBus.on(type, handler);
};
export const offEvent = (type, handler) => {
  eventBus.off(type, handler);
};
export const clearAllEvents = () => {
  eventBus.all.clear();
};
export default eventBus;