const SETTINGS_KEY = 'mgpic_game_settings';
const DEFAULT_SETTINGS = {
  controlMode: 'touchpad',
  mouseSensitivity: 0.002,
};
export function getSettings() {
  try {
    const stored = localStorage.getItem(SETTINGS_KEY);
    if (stored) {
      const settings = JSON.parse(stored);
      return { ...DEFAULT_SETTINGS, ...settings };
    }
  } catch (e) {
  }
  return { ...DEFAULT_SETTINGS };
}
export function saveSettings(settings) {
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
    return true;
  } catch (e) {
    return false;
  }
}
export function getSetting(key) {
  const settings = getSettings();
  return settings[key];
}
export function updateSetting(key, value) {
  const settings = getSettings();
  settings[key] = value;
  return saveSettings(settings);
}
export function resetSettings() {
  return saveSettings({ ...DEFAULT_SETTINGS });
}