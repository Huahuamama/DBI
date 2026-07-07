# DragonBones to Godot Native Skeleton Converter

An editor plugin designed for Godot 4 that converts **DragonBones** animations into **Godot native skeletal animations (Node2D/Skeleton2D/AnimationPlayer)** for seamless subsequent editing.

Import DragonBones files directly into Godot as fully editable native skeletal animations.

### ⚙️ Environment & Versions
*   **DragonBones Version:** 5.6
*   **Godot Version:** 4.x

### 💡 Why Use This Plugin?
Other plugins often treat imported animations as a "black box," making it extremely difficult to tweak or modify keys directly inside Godot. 
Converting your assets into native bones and `AnimationPlayer` tracks unlocks the full power of Godot's native ecosystem (like `AnimationTree` state machines) and gives you total freedom to fine-tune, rewrite, or rearrange keyframes directly in the editor timeline.

---

## ✨ Features (Perfectled Supported)

This plugin aims for lossless automated conversion and perfectly supports the following core DragonBones elements:

*   **Skeleton Tree Setup**: Automatically generates the corresponding `Skeleton2D` and `Bone2D` node hierarchies based on the DragonBones bone structure.
*   **Slot Switching**: Full support for dynamically swapping slot visibility and contents along the animation timeline.
*   **Basic Transformations**: 100% accurate translation of **Position**, **Rotation**, and **Scale** keyframe animations for both bones and slots.

---

## ⚠️ Known Issues & Limitations

To avoid potential workflow bottlenecks, please note that the following features are **currently unsupported** or may cause issues during conversion:

1.  **No IK (Inverse Kinematics) Support**
2.  **No Skin Swapping Support**
3.  **Mesh Deformation / Bounding Box Artifacts**: 
    *   If you utilized the DragonBones **Bounding Box** feature to create **deformable meshes (Mesh Deform/FFD)**, the imported images may display stretching, misalignment, or rendering artifacts in Godot. It is highly recommended to stick to rigid bone rotation/scaling for animations.
4.  **No Mid-Animation Slot Draw Order Changes**: 
    *   If your DragonBones animation alters the slot depth/z-ordering (Draw Order changes) **in the middle of a timeline**, the plugin cannot currently translate those depth changes into Godot animation keys.

---

## 🛠️ Installation

1. Copy all files from this plugin into your project's `res://addons/` directory.
2. Create a new Scene and name it `"DBI"`. 
3. Ensure the root node is set to position `(0,0)` and scale `(1,1)`. 
4. Attach the `DBImport.gd` script to this root node.

---

## 🚀 Usage

1. **Exporting from DragonBones**: Export your project as a **JSON file accompanied by multiple individual images**. *(Note: The script does NOT support texture atlases/spritesheets).*
2. In the Godot editor, select your **DBImporter** node.
3. Locate the Inspector panel and fill in the fields for **Jsonpath** and **Textpath**.
4. Click the **"Import"** checkbox to trigger the automated conversion process.
