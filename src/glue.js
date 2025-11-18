import { messageQueue, registerAllHandlers } from './messageQueue.js';
import {
  global_gacha,
  global_get_resource,
  global_craft,
  global_get_copper_list,
  global_upgrade_copper,
  global_info_subscribe,
  global_import_save,
  global_export_save,
  eventloop as eventloop_main,
} from './main.js';
registerAllHandlers();
const parse = (fn) => () => JSON.parse(fn());
export const gacha = parse(global_gacha);
export const get_resource = parse(global_get_resource);
export const craft = parse(global_craft);
export const get_copper_list = parse(global_get_copper_list);
export const upgrade_copper = (id) => JSON.parse(global_upgrade_copper(id));
export const info_subscribe = (callback) => {
  global_info_subscribe(info => {
    const message = JSON.parse(info);
    callback(message);
    messageQueue.enqueue(message);
  });
};
export const import_save = global_import_save;
export const export_save = parse(global_export_save);
export const eventloop = eventloop_main;
export { messageQueue };