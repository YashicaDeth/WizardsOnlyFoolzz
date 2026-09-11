# Impact and damage-zone concept

The Play Lab now has a non-graphic damage model that can grow into the full demolition system. Each target has a hull zone, left/right side zones, and a driver zone. A hit records the zone, changes the response, and exposes the state in the HUD.

The intended next layer is mesh-aware damage:

1. Author detachable parts as separate meshes or named sockets: `driver_head`, `arm_l`, `arm_r`, `torso`, `front_bumper`, `engine`, and `cabin`.
2. Give each socket a health budget and impact threshold. Small impacts deform or disable; heavy vehicle impacts can detach or crush the part.
3. Keep the presentation stylized and readable: sparks, smoke, bent silhouettes, missing panels, and a brief screen jolt communicate the result without requiring graphic detail.
4. Let the vehicle class and speed determine the severity. A larger car can disable a smaller car's steering or cabin, while a glancing hit only damages a side panel.
5. Separate simulation state from the visual mesh so the same damage system works with placeholder primitives and later supplied character models.

The current prototype now exposes readable driver-down, side-panel torn away, and hull-totaled states using placeholder meshes. It is ready for supplied meshes without locking the project to one character rig: imported parts can replace the same metadata sockets instead of rewriting the combat loop.
