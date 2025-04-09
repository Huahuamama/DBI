#V1.00

@tool
extends Node2D

@export_global_file("*.json") var jsonpath = "";
@export_dir var textpath = "";
@export var import : bool = false : set = dbimport

func set_texture(node, path = ""):
	if path=="":
		path=node.name
	var dir = DirAccess.open(textpath+"/"+path.get_base_dir())
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif (not file.begins_with(".")) && (file.get_basename() == path.get_file().get_basename()):
			if path.get_base_dir().length()==0:
				node.set_texture(load(textpath+"/"+file))
			else:
				node.set_texture(load(textpath+"/"+path.get_base_dir()+"/"+file))
	dir.list_dir_end()


func createAnimTrack(anim: Animation, path, firstFrame) -> int:
	var track_index = anim.add_track(Animation.TYPE_VALUE);
	anim.track_set_path(track_index, path)
	
	if firstFrame.has("tweenEasing") or firstFrame.has("curve"):
		anim.value_track_set_update_mode(track_index, Animation.UPDATE_CONTINUOUS)
	else:
		anim.value_track_set_update_mode(track_index, Animation.UPDATE_DISCRETE)

	return track_index;


func addAnimKey(anim: Animation, trackIdx: int, frameJson, time:float, key: Variant):
	var keyIndex = anim.track_insert_key(trackIdx, time, key);
	
	if frameJson.has("tweenEasing") or !frameJson.has("curve"):
		pass
	elif frameJson.has("curve"):
		if arrayEqual(frameJson.curve, [0.5,0,1,1]):
			anim.track_set_key_transition(trackIdx, keyIndex, 3);
		elif arrayEqual(frameJson.curve, [0,0,0.5,1]):
			anim.track_set_key_transition(trackIdx, keyIndex, 0.4);
		elif arrayEqual(frameJson.curve, [0.5,0,0.5,1]):
			anim.track_set_key_transition(trackIdx, keyIndex, -3);


func arrayEqual(a: Array, b: Array):
	if a.size() != b.size():
		return false;
	for i in a.size():
		if a[i]!=b[i]:
			return false;
	return true;


func dbimport(val):
	if jsonpath == "" || textpath == "":
		import=false;
		return;
	if !val:
		return;
	val=false;

	var file = FileAccess.open(jsonpath, FileAccess.READ)
	if file == null :
		return;
	var test_json_conv = JSON.new()
	test_json_conv.parse(file.get_as_text())	
	var json_result = test_json_conv.get_data()
	file = null

	#Skeleton2D build
	for i in json_result.armature.size():
		var true_vertex_oder_dict = {}

		var skeleton = Skeleton2D.new();
		skeleton.set_name(json_result.armature[i].name);
		self.add_child(skeleton);
		skeleton.set_modification_stack(SkeletonModificationStack2D.new());
		skeleton.owner = get_tree().edited_scene_root;

		var AP = AnimationPlayer.new()
		AP.set_name("Animation")
		AP.set_root("..")

		var rest = Animation.new()
		rest.set_length(0);
		
		var boneArray: Array[Bone2D] = []

		if json_result.armature[i].has("bone"):
			for b in json_result.armature[i].bone:
				var bone = Bone2D.new();
				bone.set_autocalculate_length_and_angle(false);
				if b.has("parent"):
					var par = skeleton.find_child(b.parent)
					var pointB = Vector2(0,0);
					var b_scale =  Vector2(1,1);
					if b.has("transform"):
						if b.transform.has('x'):
							pointB.x= b.transform.x
						if b.transform.has('y'):
							pointB.y= b.transform.y
						if b.transform.has("scX"):
							b_scale.x = b.transform.scX;
						if b.transform.has("scY"):
							b_scale.y = b.transform.scX;

					# When a bone does not inherit parent's transform, use RemoteTransform2D
					# not used for now
					if b.has("inheritRotation") || b.has("inheritScale"):

						par.get_parent().add_child(bone);
						var remote = RemoteTransform2D.new()
						remote.set_global_transform(bone.get_global_transform());
						if b.has("inheritRotation"):
							remote.set_update_rotation(b.inheritRotation)
						if b.has("inheritScale"):
							remote.set_update_scale(b.inheritScale)
						par.add_child(remote);
						bone.set_name(b.name);
						remote.set_name("[RE]"+bone.name)
						remote.remote_path=remote.get_path_to(bone)  #bone.get_path()

						if b.has("transform"):

							if b.transform.has("skX"):
								if b.has("inheritRotation"):
									if not b.inheritRotation:
										bone.set_global_rotation_degrees(b.transform.skX)
								remote.set_rotation_degrees(b.transform.skX)

							if b.transform.has("skY"):
								if b.has("inheritRotation"):
									if not b.inheritRotation:
										bone.set_global_rotation_degrees(b.transform.skY)
								remote.set_rotation_degrees(b.transform.skY)

						if b.has("inheritScale"):
							if not b.inheritScale:
								bone.set_global_scale(b_scale)

						remote.set_global_scale(b_scale)
						bone.set_length(0)
						remote.set_position(pointB);
						bone.set_position(pointB);
						remote.owner = get_tree().edited_scene_root

						var track = "";

						var target;

						if b.has("inheritRotation") || b.has("inheritScale"):
							target = remote;
						else:
							target = bone

						track = rest.add_track(Animation.TYPE_VALUE)
						rest.track_set_path(track, String(skeleton.get_path_to(target))+":position");
						rest.track_insert_key(track, 0, target.position);

						if b.has("inheritRotation"):
							if b.inheritRotation==false:
								target = bone;
						else:
							target = remote;

						track = rest.add_track(Animation.TYPE_VALUE)
						rest.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
						if b.has("inheritRotation") && b.inheritRotation==false:
							rest.track_set_path(track, String(skeleton.get_path_to(bone))+":global_rotation_degrees");
							rest.track_insert_key(track, 0, bone.global_rotation_degrees);
						else:
							rest.track_set_path(track, String(skeleton.get_path_to(target))+":rotation_degrees");
							rest.track_insert_key(track, 0, target.rotation_degrees);

						if b.has("inheritScale"):
							if b.inheritScale==false:
								target = bone;
						else:
							target = remote;

						track = rest.add_track(Animation.TYPE_VALUE)
						rest.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
						rest.track_set_path(track,  String(skeleton.get_path_to(target))+":scale");
						rest.track_insert_key(track, 0, target.scale);

					else:
						par.add_child(bone);
						if b.has("transform"):
							if b.transform.has("skX"):
								bone.set_rotation_degrees(b.transform.skX)
							if b.transform.has("skY"):
								bone.set_rotation_degrees(b.transform.skY)
						bone.set_name(b.name);
						bone.set_scale(b_scale)
						bone.set_length(0)
						bone.set_position(pointB);

						var track = rest.add_track(Animation.TYPE_VALUE)
						rest.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
						rest.track_set_path(track, String(skeleton.get_path_to(bone))+":position");
						rest.track_insert_key(track, 0, bone.position);

						track = rest.add_track(Animation.TYPE_VALUE)
						rest.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
						rest.track_set_path(track, String(skeleton.get_path_to(bone))+":rotation_degrees");
						rest.track_insert_key(track, 0, bone.rotation_degrees);

						track = rest.add_track(Animation.TYPE_VALUE)
						rest.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
						rest.track_set_path(track, String(skeleton.get_path_to(bone))+":scale");
						rest.track_insert_key(track, 0, bone.scale);

					if b.has("length"):
						bone.set_length(b.length)
					else:
						bone.set("editor_settings/show_bone_gizmo",false)
					bone.owner = get_tree().edited_scene_root

				else:
					bone.set_name(b.name);
					bone.set_length(0);
					var origin = Vector2(0,0);
					if b.has("transform"):
						if b.transform.has("x") :
							origin.x=b.transform.x;
						if b.transform.has("y") :
							origin.y=b.transform.y;
					bone.set_position(origin);
					skeleton.add_child(bone)
					bone.owner = get_tree().edited_scene_root

					var track = "";
					var path = String(skeleton.get_path_to(bone))

					track = rest.add_track(Animation.TYPE_VALUE)
					rest.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
					rest.track_set_path(track, path+":position");
					rest.track_insert_key(track, 0, bone.position);

					track = rest.add_track(Animation.TYPE_VALUE)
					rest.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
					rest.track_set_path(track, path+":rotation_degrees");
					rest.track_insert_key(track, 0, bone.rotation_degrees);

					track = rest.add_track(Animation.TYPE_VALUE)
					rest.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
					rest.track_set_path(track, path+":scale");
					rest.track_insert_key(track, 0, bone.scale);

				bone.rest=bone.transform
				boneArray.append(bone)

		if json_result.armature[i].has("slot"):
			var masterslot = Node2D.new()
			var slotscript = load("res://addons/DBI/slots.gd")
			masterslot.set_script(slotscript)
			masterslot.set_name("SLOTS")

			skeleton.add_child(masterslot)
			masterslot.owner = get_tree().edited_scene_root

			for sl in json_result.armature[i].slot.size():
				var slot = Node2D.new();
				slot.set_name(json_result.armature[i].slot[sl].name)
				true_vertex_oder_dict[json_result.armature[i].slot[sl].name] = {}
				if json_result.armature[i].slot[sl].has("color"):
					var C = Color(1,1,1,1);
					if json_result.armature[i].slot[sl].color.has("aM"):
						C.a=json_result.armature[i].slot[sl].color.aM/100
					if json_result.armature[i].slot[sl].color.has("rM"):
						C.r=json_result.armature[i].slot[sl].color.rM/100
					if json_result.armature[i].slot[sl].color.has("gM"):
						C.g=json_result.armature[i].slot[sl].color.gM/100
					if json_result.armature[i].slot[sl].color.has("bM"):
						C.b=json_result.armature[i].slot[sl].color.bM/100
					slot.set_modulate(C)
				masterslot.add_child(slot);
				slot.owner = get_tree().edited_scene_root

				# var track = rest.add_track(Animation.TYPE_VALUE)
				# rest.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
				# rest.track_set_path(track, String(skeleton.get_path_to(slot))+":modulate");
				# rest.track_insert_key(track, 0, slot.modulate);

			masterslot.set_rest()

			var track = rest.add_track(Animation.TYPE_VALUE)
			rest.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
			rest.track_set_path(track, String(skeleton.get_path_to(masterslot))+":sl_oder");
			rest.track_insert_key(track, 0, masterslot.sl_oder);

			for j in json_result.armature[i].skin.size():
				for k in json_result.armature[i].skin[j].slot.size():
					if json_result.armature[i].skin[j].slot[k].has("display"):
						var display;
						for d in json_result.armature[i].skin[j].slot[k].display.size():
							if json_result.armature[i].skin[j].slot[k].display[d].has("type"):
								if json_result.armature[i].skin[j].slot[k].display[d].type == "mesh" || json_result.armature[i].skin[j].slot[k].display[d].type == "boundingBox" :
									var display_json = json_result.armature[i].skin[j].slot[k].display[d]
									display = Polygon2D.new();
									var s_name = json_result.armature[i].skin[j].slot[k].display[d].name
									if s_name.rfind("/")!=-1:
										s_name = s_name.substr(s_name.rfind("/")+1)
									display.set_name(s_name)

									if display_json.type == "mesh":
										if(json_result.armature[i].skin[j].slot[k].display[d].has("path")):
											set_texture(display,json_result.armature[i].skin[j].slot[k].display[d].path)
										else:
											set_texture(display,json_result.armature[i].skin[j].slot[k].display[d].name)

										var true_oder = PackedVector2Array()

										for v in range(0,display_json.vertices.size(),2):
											true_oder.push_back(Vector2(display_json.vertices[v],display_json.vertices[v+1]));

										var points2 = PackedVector2Array();
										for p in range(0,display_json.edges.size()-1,2):
											points2.push_back(true_oder[display_json.edges[p]])
										var internal = true_oder.size()-points2.size();

										if true_oder.size() >= display_json.edges.max()+1:
											for p in true_oder.size():
												if points2.find(true_oder[p])==-1:
													points2.push_back(true_oder[p]);
										display.set_polygon(points2);

										display.set_internal_vertex_count(internal);
										var triangles = [];
										for v in range(0,display_json.triangles.size(),3):
											var true_1 = display.polygon.find(true_oder[display_json.triangles[v]])
											var true_2 = display.polygon.find(true_oder[display_json.triangles[v+1]])
											var true_3 = display.polygon.find(true_oder[display_json.triangles[v+2]])
											triangles.push_back(PackedInt32Array([true_1,true_2,true_3]))

										display.set_polygons(triangles);
										if display_json.has("uvs"):
											var uvs = PackedVector2Array();
											uvs.resize(display.polygon.size())
											var iter = 0;
											for v in range(0,display_json.uvs.size(),2):
												var true_1 = display.polygon.find(true_oder[iter])
												uvs[true_1]=Vector2(display_json.width*display_json.uvs[v],display_json.height*display_json.uvs[v+1]);
												iter += 1
											display.set_uv(uvs);

										if json_result.armature[i].skin[j].slot[k].display[d].has("weights"):
											var arr = json_result.armature[i].skin[j].slot[k].display[d].weights;
											var bones = {}
											var index = 0;
											var vert_num = 0;
											while index<arr.size():
												var affected=arr[index]*2
												for w_bone in range(1,affected,2):
													var bone_path=skeleton.find_child(json_result.armature[i].bone[arr[index+w_bone]].name).get_path();
													if not (bones.has(bone_path)):
														bones[bone_path] = [];
														bones[bone_path].resize(display.polygon.size())
													bones[bone_path][display.polygon.find(true_oder[vert_num])]=arr[index+w_bone+1]
												index+=(arr[index]*2)+1
												vert_num+=1
											for wb in bones.keys().size():
												display.add_bone(bones.keys()[wb],bones[bones.keys()[wb]])

										else:
											for sl in json_result.armature[i].slot.size():
												if json_result.armature[i].slot[sl].name==json_result.armature[i].skin[j].slot[k].name:
													var bone_path = skeleton.find_child(json_result.armature[i].slot[sl].parent).get_path();
													var wbone = []
													wbone.resize(display.polygon.size());
													wbone.fill(1.0)
													display.add_bone(bone_path,wbone);
											display.set_skeleton(skeleton.get_path())
										var trans = Transform2D()

										skeleton.find_child("SLOTS",false).find_child(json_result.armature[i].skin[j].slot[k].name,false).add_child(display)
										if json_result.armature[i].skin[j].slot[k].display[d].has("weights"):
											display.position=Vector2(0,0)
										else:
											for sl in json_result.armature[i].slot.size():
												if json_result.armature[i].slot[sl].name==json_result.armature[i].skin[j].slot[k].name:
													var vec = PackedVector2Array();
													for p in display.polygon.size():
														trans = skeleton.find_child(json_result.armature[i].slot[sl].parent).get_global_transform()
														vec.push_back(trans*display.polygon[p])
													display.set_polygon(vec);
													vec.clear();

										display.set_skeleton(skeleton.get_path())
										if(json_result.armature[i].skin[j].slot[k].display[d].has("path")):
											set_texture(display,json_result.armature[i].skin[j].slot[k].display[d].path)
										else:
											set_texture(display)
										display.owner = get_tree().edited_scene_root
										true_vertex_oder_dict[json_result.armature[i].skin[j].slot[k].name][display.name]={"oder" : true_oder, "edges" : display_json.edges, "transformation" : trans}

										track = rest.add_track(Animation.TYPE_VALUE);
										rest.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
										rest.track_set_path(track, String(skeleton.get_path_to(display))+":polygon");
										rest.track_insert_key(track, 0, display.polygon);

									elif display_json.type == "boundingBox":

										var true_oder = PackedVector2Array()

										for v in range(0,display_json.vertices.size(),2):
											true_oder.push_back(Vector2(display_json.vertices[v],display_json.vertices[v+1]));
										display.set_polygon(true_oder)
										
										for sl in json_result.armature[i].slot.size():
											display.transform=skeleton.find_child(json_result.armature[i].slot[sl].parent).get_global_transform()
											if json_result.armature[i].slot[sl].name==json_result.armature[i].skin[j].slot[k].name:
												var bone_path = skeleton.find_child(json_result.armature[i].slot[sl].parent).get_path();
												var bone_weights = []
												for bw in display.polygon.size():
													bone_weights.push_back(1);
												display.add_bone(bone_path,bone_weights);
										skeleton.find_child("SLOTS",false).find_child(json_result.armature[i].skin[j].slot[k].name,false).add_child(display)
										display.set_skeleton(skeleton.get_path())

										display.owner = get_tree().edited_scene_root
								if json_result.armature[i].skin[j].slot[k].display[d].type == "armature":
									pass

							else:
								display = Sprite2D.new()

								if json_result.armature[i].skin[j].slot[k].display[d].has("transform"):
									display.position=Vector2(0,0)
									if json_result.armature[i].skin[j].slot[k].display[d].transform.has("x"):
										display.position.x=json_result.armature[i].skin[j].slot[k].display[d].transform.x
									if json_result.armature[i].skin[j].slot[k].display[d].transform.has("y"):
										display.position.y=json_result.armature[i].skin[j].slot[k].display[d].transform.y

								var s_name = json_result.armature[i].skin[j].slot[k].display[d].name
								if s_name.rfind("/")!=-1:
									s_name = s_name.substr(s_name.rfind("/")+1)
								display.set_name(s_name);

								if(json_result.armature[i].skin[j].slot[k].display[d].has("path")):
									set_texture(display,json_result.armature[i].skin[j].slot[k].display[d].path)
								else:
									set_texture(display,json_result.armature[i].skin[j].slot[k].display[d].name)

								var p_bone;

								for sl in json_result.armature[i].slot.size():
									if json_result.armature[i].slot[sl].name==json_result.armature[i].skin[j].slot[k].name:
										p_bone = skeleton.find_child(json_result.armature[i].slot[sl].parent)
										break;

								if json_result.armature[i].skin[j].slot[k].display[d].has("transform"):
									if json_result.armature[i].skin[j].slot[k].display[d].transform.has("skX"):
										display.set_rotation_degrees((json_result.armature[i].skin[j].slot[k].display[d].transform.skX))
									if json_result.armature[i].skin[j].slot[k].display[d].transform.has("scX"):
										display.scale.x=json_result.armature[i].skin[j].slot[k].display[d].transform.scX
									if json_result.armature[i].skin[j].slot[k].display[d].transform.has("scY"):
										display.scale.y=json_result.armature[i].skin[j].slot[k].display[d].transform.scY
								display.transform=p_bone.global_transform*display.transform;
								skeleton.find_child("SLOTS",false).find_child(json_result.armature[i].skin[j].slot[k].name,false).add_child(display)

								var remote = null;
								for c in p_bone.get_children():
									if c is RemoteTransform2D && c.name == display.name:
										remote = c;
								if remote == null:
									remote = RemoteTransform2D.new()
									remote.set_name(display.name)
									p_bone.add_child(remote);
									remote.set_global_transform(display.get_global_transform());
									remote.remote_path=remote.get_path_to(display)
									remote.owner = get_tree().edited_scene_root
								display.owner = get_tree().edited_scene_root

			var slots = masterslot.get_children();
			slotscript = load("res://addons/DBI/slot.gd")
			for sl in slots.size():
				slots[sl].set_script(slotscript)
				if json_result.armature[i].slot[sl].has("displayIndex"):
					slots[sl].current = json_result.armature[i].slot[sl].displayIndex
				else:
					slots[sl].current = 0

				track = rest.add_track(Animation.TYPE_VALUE)
				rest.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
				rest.track_set_path(track, String(skeleton.get_path_to(slots[sl]))+":current");
				rest.track_insert_key(track, 0, slots[sl].current);
#				slots[sl].set_script(null)
#			masterslot.set_script(null)

		if json_result.armature[i].has("ik"):
			for ik in json_result.armature[i].ik.size():
				var bone1 = skeleton.find_child(json_result.armature[i].ik[ik].bone)
				var bone2 = skeleton.find_child(json_result.armature[i].ik[ik].bone).get_parent();
				var Tbone = skeleton.find_child(json_result.armature[i].ik[ik].target)
				var LA = SkeletonModification2DLookAt.new()
				LA.set_bone2d_node(skeleton.get_path_to(bone1));
				LA.set_target_node(skeleton.get_path_to(Tbone));
				LA.set_bone_index(bone1.get_index())
				skeleton.get_modification_stack().add_modification(LA);

				var TIK = SkeletonModification2DTwoBoneIK.new()
				TIK.set_target_node(skeleton.get_path_to(Tbone))
				TIK.set_joint_one_bone2d_node(skeleton.get_path_to(bone2));
				TIK.set_joint_one_bone_idx(bone2.get_index());
				TIK.set_joint_two_bone2d_node(skeleton.get_path_to(bone1));
				TIK.set_joint_two_bone_idx(bone1.get_index());
				if json_result.armature[i].ik[ik].has("bendPositive"):
					TIK.set_flip_bend_direction(not json_result.armature[i].ik[ik].bendPositive)

				skeleton.get_modification_stack().add_modification(TIK);
				skeleton.get_modification_stack().set_enabled(true)

		
#		for b in boneArray:
#			b.set_autocalculate_length_and_angle(true)

		if not json_result.armature[i].has("animation"):
			return
		skeleton.add_child(AP)
		AP.owner = get_tree().edited_scene_root
		var AL = AnimationLibrary.new()

		for an in json_result.armature[i].animation:
			var animation = Animation.new()
			var length=1;
			var framerate = 1/json_result.armature[i].frameRate

			if an.has("duration"):
				length=an.duration*framerate
#actions
			if an.has("frame"):
				pass;

			if an.has("bone"):
				for bone in an.bone:
					if bone.has("translateFrame"):
						var write_head=0;
						var bone_position;
						var path;
						var bone_ref = skeleton.find_child("[RE]"+bone.name)
						if bone_ref == null:
							bone_ref = skeleton.find_child(bone.name);

						bone_position = bone_ref.position
						path = String(skeleton.get_path_to(bone_ref))+":position"
						var track_pos_index = createAnimTrack(animation, path,bone.translateFrame[0]);

						for frame in bone.translateFrame:

							var newPos = bone_position
							if  frame.has("x"):
								newPos.x+=frame.x
							if  frame.has("y"):
								newPos.y+=frame.y
							addAnimKey(animation, track_pos_index, frame, write_head, newPos);
							if frame.has("duration"):
								write_head+=frame.duration*framerate
							else:
								write_head+=framerate

					if bone.has("rotateFrame"):
						var write_head=0;
						var bone_rot;
						var path;
						var bone_ref = skeleton.find_child("[RE]"+bone.name)
						if bone_ref == null:
							bone_ref = skeleton.find_child(bone.name)
							bone_rot = skeleton.find_child(bone.name).rotation_degrees
							path = String(skeleton.get_path_to(skeleton.find_child(bone.name)))+":rotation_degrees"
						else:
							if not bone_ref.update_rotation:  #use global rotation
								bone_rot = skeleton.find_child(bone.name).global_rotation_degrees # + 90
								path = String(skeleton.get_path_to(skeleton.find_child(bone.name)))+":global_rotation_degrees"
							else:
								bone_rot = skeleton.find_child("[RE]"+bone.name).rotation_degrees
								path = String(skeleton.get_path_to(skeleton.find_child("[RE]"+bone.name)))+":rotation_degrees"

						var track_index = createAnimTrack(animation, path,bone.rotateFrame[0]);

						var cwRot = 0;
						var newRot  = 0;
						var offset = 0;

						for f in bone.rotateFrame.size():
							newRot = bone_rot

							if  bone.rotateFrame[f].has("rotate"):
								newRot += bone.rotateFrame[f].rotate

							newRot += cwRot+offset
							offset += cwRot

							cwRot=0;
							if  bone.rotateFrame[f].has("clockwise"):
								cwRot = 360*(bone.rotateFrame[f].clockwise);
							addAnimKey(animation, track_index, bone.rotateFrame[f], write_head, newRot);

							if  bone.rotateFrame[f].has("duration"):
								write_head+=bone.rotateFrame[f].duration*framerate
							else:
								write_head+= framerate

					if bone.has("scaleFrame"):

						var write_head=0;
						var s_scale;
						var path;
						var bone_ref = skeleton.find_child("[RE]"+bone.name)

						if bone_ref == null:
							s_scale = skeleton.find_child(bone.name).scale
							path = String(skeleton.get_path_to(skeleton.find_child(bone.name)))+":scale"
						else:
							if not bone_ref.update_scale:
								s_scale = skeleton.find_child(bone.name).scale
								path = String(skeleton.get_path_to(skeleton.find_child(bone.name)))+":scale"
							else:
								s_scale = skeleton.find_child("[RE]"+bone.name).scale
								path = String(skeleton.get_path_to(skeleton.find_child("[RE]"+bone.name)))+":scale"

						var track_id = createAnimTrack(animation, path, bone.scaleFrame[0]);

						for f in bone.scaleFrame.size():
							var newScale = s_scale
							if  bone.scaleFrame[f].has("x"):
								newScale.x = bone.scaleFrame[f].x
							if  bone.scaleFrame[f].has("y"):
								newScale.y = bone.scaleFrame[f].y
							addAnimKey(animation,track_id, bone.scaleFrame[f], write_head, newScale);
							var d = bone.scaleFrame[f].get("duration")
							if d==null:
								d = 1
							write_head+=d*framerate

			if an.has("ffd"):
				for ffdi in an.ffd.size():
					var track_ffd_index = animation.add_track(Animation.TYPE_BEZIER)

					var track_start = animation.add_track(Animation.TYPE_VALUE)
					animation.value_track_set_update_mode(track_start,Animation.UPDATE_DISCRETE)

					var track_end = animation.add_track(Animation.TYPE_VALUE)
					animation.value_track_set_update_mode(track_end,Animation.UPDATE_DISCRETE)

					var f_name = an.ffd[ffdi].name

					if f_name.rfind("/")!=-1:
						f_name = f_name.substr(f_name.rfind("/")+1)

					skeleton.find_child("SLOTS",false).find_child(an.ffd[ffdi].slot,false).find_child(f_name).set_script(load("res://addons/DBI/PolyEaseCurve.gd"))

					var path = String(skeleton.get_path_to(skeleton.find_child("SLOTS",false).find_child(an.ffd[ffdi].slot,false).find_child(f_name)))
					animation.track_set_path(track_ffd_index, path+":delta");

					animation.track_set_path(track_start, path+":start");
					animation.track_set_path(track_end, path+":end");

					if an.ffd[ffdi].has("frame"):
						var write_head=0;
						var frames = [];
						for f in an.ffd[ffdi].frame.size():
							var offset=0
							var nextvec = true_vertex_oder_dict[an.ffd[ffdi].slot][f_name].oder.duplicate()

							if an.ffd[ffdi].frame[f].has("offset"):
								offset = an.ffd[ffdi].frame[f].offset

							if an.ffd[ffdi].frame[f].has("vertices"):
								var vert_arr = []
								for v in nextvec.size():
									vert_arr.push_back(nextvec[v].x)
									vert_arr.push_back(nextvec[v].y)

								for v in an.ffd[ffdi].frame[f].vertices.size():
									vert_arr[offset]+=an.ffd[ffdi].frame[f].vertices[v]
									offset+=1

								nextvec.clear();

								for v in range(0,vert_arr.size(),2):
									nextvec.push_back(Vector2(vert_arr[v],vert_arr[v+1]))

							var keyframe = PackedVector2Array()
							var edges = true_vertex_oder_dict[an.ffd[ffdi].slot][f_name].edges;
							var trans = true_vertex_oder_dict[an.ffd[ffdi].slot][f_name].transformation

							for p in range(0,edges.size()-1,2):
								keyframe.push_back(trans*nextvec[edges[p]])
							for p in nextvec.size():
								if not edges.has(float(p)):
									keyframe.push_back(trans*nextvec[p])

							frames.push_back(write_head)
							frames.push_back(keyframe)
							write_head+=an.ffd[ffdi].frame[f].duration*framerate
						
						#print(frames);  #111
						for f in range(0,frames.size(),2):
							if(f!=0):
								if(f+3<frames.size()):
									animation.bezier_track_insert_key(track_ffd_index, frames[f]+0.0001, 0);
							else:
								animation.bezier_track_insert_key(track_ffd_index, frames[f], 0);			

							if(f+3<frames.size()): #if is not the last key frame,add 1 for next key
								animation.bezier_track_insert_key(track_ffd_index, frames[f+2], 1);
								if(f>0):
									animation.track_insert_key(track_start, frames[f]+0.0001, frames[f+1])
									animation.track_insert_key(track_end,   frames[f]+0.0001, frames[f+3])
								else:
									animation.track_insert_key(track_start, frames[f], frames[f+1])
									animation.track_insert_key(track_end,   frames[f], frames[f+3])

			if an.has("slot"):
				for sl in an.slot:

					if sl.has("colorFrame"):
						var write_head=0;
						var slot = skeleton.find_child("SLOTS",false).find_child(sl.name)
						var path = String(skeleton.get_path_to(slot))+":modulate"
						var track = createAnimTrack(animation, path, sl.colorFrame[0]);

						if(rest.find_track(path, Animation.TYPE_VALUE)==-1):
							var rest_track = rest.add_track(Animation.TYPE_VALUE)
							rest.track_set_path(rest_track, path)
							rest.track_insert_key(rest_track, write_head, slot.current);

						for frame in sl.colorFrame:
							var value = Color(1,1,1,1);
							if frame.has("value"):
								if frame.value.has("aM"):
									value.a = frame.value.aM/100
								if frame.value.has("rM"):
									value.r = frame.value.rM/100
								if frame.value.has("gM"):
									value.g = frame.value.gM/100
								if frame.value.has("bM"):
									value.b = frame.value.bM/100
							addAnimKey(animation, track, frame, write_head, value);
							write_head+=frame.duration*framerate

					if sl.has("displayFrame"):
						var write_head=0;
						var slot = skeleton.find_child("SLOTS",false).find_child(sl.name)
						var track_slot_index = animation.add_track(Animation.TYPE_VALUE)
						animation.value_track_set_update_mode(track_slot_index,Animation.UPDATE_DISCRETE)
						var path = String(skeleton.get_path_to(slot))+":current"
						animation.track_set_path(track_slot_index, path);
#move to init or don't give a fuck
						if(rest.find_track(path, Animation.TYPE_VALUE)==-1):
							var track = rest.add_track(Animation.TYPE_VALUE)
							rest.track_set_path(track, path)
							rest.track_insert_key(track, write_head, slot.current);

						for frame in sl.displayFrame.size():
							var value = 0;
							if sl.displayFrame[frame].has("value"):
								value = sl.displayFrame[frame].value
							animation.track_insert_key(track_slot_index, write_head, value)
							if sl.displayFrame[frame].has("duration"):
								write_head+=sl.displayFrame[frame].duration*framerate
							else:
								write_head += framerate

			if an.has("zOrder"):
				if an.zOrder.has("frame"):
					var slots = skeleton.find_child("SLOTS")
					var track_slot_index = animation.add_track(Animation.TYPE_VALUE)
					animation.value_track_set_update_mode(track_slot_index,Animation.UPDATE_DISCRETE)
					var path = String(skeleton.get_path_to(slots))+":sl_oder"
					animation.track_set_path(track_slot_index, path);
					var write_head=0
					for frame in an.zOrder.frame.size():
						var arr = []
						if an.zOrder.frame[frame].has("zOrder"):
							arr = an.zOrder.frame[frame].zOrder
						animation.track_insert_key(track_slot_index, write_head, arr)
						write_head+=an.zOrder.frame[frame].duration*framerate
#bend direction and weight
			if an.has("ik"):
				pass;

			animation.set_length(length);
			AL.add_animation(an.name, animation)

		AL.add_animation("RESET",rest);
		AP.add_animation_library("", AL)
