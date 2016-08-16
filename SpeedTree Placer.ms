/*
[INFO]

NAME = SpeedTree Placer
VERSION = 1.2.9
AUTHOR = MastaMan
DEV = SightLine Vision
HELP = 


[1.0.0]

* First release =

[1.2.3]

* Changed scatter menu and algorithm=
* Small bug fixes=
+ Add function set alias for selected objects=

[1.2.6]

-BugFix: Dublicate items bug when pick tree=
-BugFix: Error when delete trees with hotkey Alt=

[1.2.7]

+ Added: Drop Trees section with drop features=
* Adopted for Unreal=

[1.2.8]
+ Added: Preview trees=

[1.2.9]

* Now build trees list from actually files for Unreal=
- BugFix: Error when delete boxes in Alt + Place mode=
+ Added: Paint features=
+ Added: Brush size option=

[ABOUT]

It is full-featrured script for place and scatter=
"SpeedTree" boxes in 3Ds Max scene.=

[SCRIPT]
*/

fn getScriptInfo s releaseInfo: "" =
(		
	if(releaseInfo != "") do
	(
		r = getINISetting s releaseInfo
		return r
	)
	
	v = getINISetting s "INFO" "VERSION"
	a = getINISetting s "INFO" "AUTHOR"
	n = getINISetting s "INFO" "NAME"
	o = getINISetting s "ABOUT"
	c = getINISetting s "INFO" "DEV"
	h = getINISetting s "INFO" "HELP"
	
	r = for i in (getINISetting s) where i != "ABOUT" and i != "SCRIPT" and i != "COPY" collect i
	
	return #(n, a, v, o, r, c, h)
)

fn parseToLine m = 
(
	if(m.count == 0) do return ""
	
	l = ""				
	for i in m do l += i + "\n"
	return l
)


try(closeRolloutFloater rSpeedTreePlacer)catch()
global rSpeedTreePlacer = newRolloutFloater "SpeedTree Placer" 280 960

/* 1 - TreeName; 2 - Z pos; 3 - Color; 4 - Scale; 5 - Size; 6 - Alias; 7 - Brush Size*/
global Trees = #()
global objectsInRow = #()
global bTreesChecked = false
global rPlacer
global rScatter
global hPickedShape = undefined
global szSpeedTreeFolder = ""
global iWindowPos = [0.0, 0.0]

-- Previews for NEO and Unreal
global szPreviewsPath = #(@"d:\content\speedtree\Speedtree_UE\preview\", @"d:\content\speedtree\Speedtree_UE\preview\")


fn useSettings k p w =
(	
	d = getFilenamePath  (getThisScriptFilename())
	n = filenameFromPath (getThisScriptFilename())			
	settingsFile = d + @"ini\" + (sysInfo.username) + "_" + n + ".ini"
	szUser = sysInfo.computername
	case w of
	(
		0:
		(
			s = getINISetting settingsFile szUser k
			case p of
			(
				"int": return s as integer
				"float": return s as float
				"bool": if s == "true" then true else false
				default: return s
			)
		)
		default: return setINISetting settingsFile szUser k (p as string)
	)
)

fn CreateDummy n c =
(
	o = #()
	o = for i in helpers where i.name == n and classOf i == Point collect i
	
	if(o.count == 0) do
	(
		p = Point pos: [0, 0 ,0] box: true cross: false name: n wirecolor: c
		
		h = for i in helpers where classOf i == Point collect i
		
		try(p.pos.x =  h[h.count - 1].pos.x + p.size)catch()
	)
)

fn LinkDummy n z =
(
	o = #()
	o = for i in helpers where i.name == n and classOf i == Point collect i

	if(o.count != 0 and z.count != 0) do		
	(
		for i in z do
		(
			append o[1].children i
			i.wirecolor = o[1].wirecolor
		)
	)
)

fn createTree id p = 
(					
	s = Trees[id][4]
	
	if(rPlacer.cbxRandomScale.checked == true) do
	(
		k = (Trees[id][4] / 100.0) * rPlacer.spnRandomScalePercent.value
	
		s = random (Trees[id][4] - k) (Trees[id][4] + k)
	)

	n = uniqueName (Trees[id][1] + "_")
	in coordsys grid b = Box pos: p width: Trees[id][5] height: Trees[id][5] length: Trees[id][5] scale: [s, s, s] wirecolor: Trees[id][3] name: n 
	
	
	for i in helpers where i.name == Trees[id][1] do 
	(
		append i.children b
		exit
	)
	
	setUserProp b "Alias" Trees[id][6]
	
	if(rPlacer.cbxRandomRotate.checked == true) do b.rotation.controller.value = eulerAngles 0 0 (random 0 360)
		
	return b
)

fn saveWindowPos =
(
	useSettings "x"  iWindowPos[1] 1
	useSettings "y"  iWindowPos[2] 1		
)

fn SelectedDir p =
(
	try
	(
		p = filterString  p "\\"
		i = p.count - 2

		return p[i]
	)
	catch
	(
		return p[p.count]
	)
)

fn stripName n =
(
	return trimRight n "_&0123456789"
)

rollout rPlacer "Trees List"
(	
	group "Engine"
	(
		radiobuttons rdoExportFor  "" labels:#("Neo", "Unreal Engine") align: #left columns: 1
	)
	
	group "Project"
	(
		edittext edtBrowse "" width:253 height:25 readOnly:true text: "Please select speedtree folder" offset: [-7, 0]
		button btnBrowse "Browse" width:250 height:35
	)
	
	global Clr = dotNetClass "System.Drawing.Color"	
	dotNetControl lbxTrees "system.windows.forms.listView" height:265 width: 260	offset:[-10, 0]
	
	group "Preview"
	(
		--bitmap btmPreview "" height: 100 width: 100 align: #left across: 2 
		button btmPreview "No preview" height: 100 width: 100 align: #left across: 2 border: false
		label lblInfo "Info:\n\nSize: \n" align: #left width: 143 height: 100 offset: [-13, 0]

	)
		
	button btnAddReferenceTree "Add" width:100 height:25 across: 2 offset: [0, 5] toolTip: "Add Tree To List" enabled: false
	button btnDublicateReferenceTree "Dublicate" width:100 height:25 offset: [0, 5] toolTip: "Dublicate Tree In List"
		
	button btnSelectReferenceTree "Select" width:100 height:25 across: 2 offset: [0, 5] toolTip: "Select Tree In Viewport"
	button btnDeleteReferenceTree "Delete" width:100 height:25 offset: [0, 5] toolTip: "Delete Tree From List"

	timer tmrColor "" active: false interval: 1000
	timer tmrPreview "" active: false interval: 1
	
	group "Parameters"
	(
		spinner spnScale "Scale:" range:[0.001,99999,1]  fieldWidth: 40 align: #left across: 3
		spinner spnSize "Size:" range:[0.01,99999, (units.decodeValue "100.0cm")] fieldWidth: 40 type: #worldunits
		spinner spnZ "Z:" range:[0,99999,1] fieldWidth: 40 type: #worldunits
		editText edtAliasName "Alias:" width: 170 across: 2
		colorPicker cpColor "" color: (color 0 0 0) width: 70 offset: [50, -2]
	)

	group "Place Settings"
	(		
		checkbox cbxRandomRotate "Random Rotate" checked: true
		checkbox cbxRandomScale "Random Scale ±" across: 3 checked:true
		spinner spnRandomScalePercent  range:[0,99999,10] scale:5 fieldWidth: 40 offset: [-10, 0]
		label lblPercent "%" offset: [-43, 0]		
		spinner spnBrushSize "Brush Size:" range: [(units.decodeValue "10cm"), (units.decodeValue "3000cm"), (units.decodeValue "500cm")] fieldWidth: 60 type: #worldunits align: #right offset: [-115, 0]
		spinner spnDistance "Distance:   " range: [(units.decodeValue "10cm"), 99999999, (units.decodeValue "200cm")] fieldWidth: 60 type: #worldunits align: #right offset: [-115, 0]
		checkbox cbxPlaceOnSurface "Place On Ground    (" checked: false across: 2				
		checkbox cbxFollowDirection "Follow Direction)" checked: false
	)
	
	checkButton btnPlaceTree "Place" width:180 height:45
	radiobuttons rdoMode "" labels: #("Placer", "Painter") columns: 2			

	fn placeMode =
	(
		a = rdoMode.state
		
		case a of
		(
			2: 
			(
				spnBrushSize.enabled =  true
				cbxPlaceOnSurface.enabled = false
				cbxFollowDirection.enabled = false
				btnPlaceTree.caption = "Paint"
			)
			default:
			(
				spnBrushSize.enabled =  false
				cbxPlaceOnSurface.enabled = true
				cbxFollowDirection.enabled = true
				btnPlaceTree.caption = "Place"
			)
		)
		
		return a
	)
	
	fn disableUI d place: false =
	(
		for i in rPlacer.controls do i.enabled = d
		rPlacer.btnBrowse.enabled = not place
		rPlacer.rdoExportFor.enabled = not place
		rPlacer.btnPlaceTree.enabled = d or place
		
		if(not place) do placeMode()
	)

	fn sessionSave =
	(
		s = ""
		for i in Trees do
		(			
			for z in 1 to 6 do s += (i[z] as string + "|")
			s += "\n"
		)
				
		try(fileProperties.addProperty #custom "SpeedTree Placer Session" s) catch()
	)
	
	fn sessionLoad =
	(		
		i = fileProperties.findProperty #custom "SpeedTree Placer Session"

		if(i == 0) do return false
		
		t = fileProperties.getPropertyValue #custom i
		
		t = filterString t "\n"
				
		Trees = #()	
		
		for i in t do
		(
			s = filterString i "|"
			
			if(s == undefined) do continue
			
			Tree = #()
			
			c = filterString s[3] "()color "
			c = for p in c collect p as float
			
			Tree[1] = s[1] as string
			Tree[2] = s[2] as float
			Tree[3] = [c[1], c[2], c[3]] as color
			Tree[4] = s[4] as float
			Tree[5] = s[5] as float
			Tree[6] = s[6] as string
			
			append Trees Tree
			
			CreateDummy Tree[1] Tree[3]
		)
		
		rPlacer.reloadTreesList()
	)
	
	fn getID =
	(			
		c = lbxTrees.Items.Count - 1
		
		for i in 0 to c where lbxTrees.Items.Item[i].Focused == true do return i + 1
		return 0
	)
	
	fn findByAlias o a =
	(
		return for i in o where (getUserProp i "Alias") == a collect i
	)
	
	fn initDotNet =
	(				
		lbxTrees.Clear()
		lbxTrees.View = (dotNetClass "System.Windows.Forms.View").Details	
		lbxTrees.FullRowSelect = true
		lbxTrees.GridLines = true		
		lbxTrees.ShowItemToolTips = true
		lbxTrees.MultiSelect = false
		lbxTrees.CheckBoxes = true
		lbxTrees.HideSelection = false
		lbxTrees.Columns.Add "Name" (lbxTrees.Width - 100)
		lbxTrees.Columns.Add "Alias" 95
		lbxTrees.LabelEdit = false
				
		lbxTrees.Update()
		lbxTrees.Refresh()
		lbxTrees.Refresh()	
	)
	
	fn addToLbxList r =
	(
		lbxTrees.Items.Clear()
		rows = #()	
		i = 1
		
		for x in r do	
		(			
			li = dotNetObject "System.Windows.Forms.ListViewItem" ""
			
			li.text = (i as string + ". " + x[1])	
			li.subitems.add (x[2] as string)
			
			append rows li		
			
			i += 1
		)
		
		lbxTrees.Items.addRange rows
	)
	
	fn getParams id =
	(
		spnScale.value = try(Trees[id][4]) catch(1.0)
		spnZ.value = try(Trees[id][2]) catch(0.0)
		spnSize.value = try(Trees[id][5]) catch(units.decodeValue "100.0cm")
		cpColor.color = try(Trees[id][3]) catch((color 0 0 0))
		edtAliasName.text = try(Trees[id][6]) catch("")
		
		m = "Info: "
		m += "\n\nAlias: " + edtAliasName.text 
		m += "\nScale: " + spnScale.value as string
		m += "\nSize: " + spnSize.value as string
		m += "\nZ: " + spnZ.value as string
		
		lblInfo.caption = m
		--rScatter.spnScatterDistance.value = spnSize.value
	)
	
	fn SelectedColorLbxList id =
	(				
		c = lbxTrees.Items.Count - 1
		
		for i in 0 to c do
		(			
			lbxTrees.Items.Item[i].BackColor = Clr.White
			lbxTrees.Items.Item[i].ForeColor = Clr.Black
			lbxTrees.Items.Item[i].Selected = false
		)
		
		try
		(
			if(id == 0) do id = getID() - 1
						
			lbxTrees.Items.Item[id].BackColor = Clr.DodgerBlue
			lbxTrees.Items.Item[id].ForeColor = Clr.White
			lbxTrees.Items.Item[id].Focused = true			
			getParams (id + 1)
			--lbxTrees.EnsureVisible(id)				
		)
		catch()				
	)
		
	fn getCheckedLbxListID =
	(
		c = lbxTrees.Items.Count - 1
		z = for i = 0 to c where c > 0 and lbxTrees.Items.Item[i] != undefined and lbxTrees.Items.Item[i].Checked == true collect i		
		return z					
	)
	
	fn reloadTreesList =
	(
		id = getID()
		
		initDotNet()
		
		k = #()
		
		for i in Trees where i[1] != undefined do
		(
			z = #()
						
			z[1] = trimRight i[1] "_"
			
			z[2] = ""
			if(i[1] != i[6]) do z[2] = i[6]
						
			append k z
		)
		
		addToLbxList k
			
		try(lbxTrees.Items.Item[id - 1].Focused = true) 
		catch
		(
			try
			(
				lbxTrees.Items.Item[0].Focused = true
				id = 1
			) 
			catch
			(
				id = 0
			)
		)
		
		getParams id
		
		tmrPreview.active = true
					
		SelectedColorLbxList 0				
	)

	fn setParams =
	(
		id = getID()
		
		if(id == 0) do return false
		
		Trees[id][4] = spnScale.value
		Trees[id][2] = spnZ.value
		Trees[id][5] = spnSize.value
				
		getParams id
		
		sessionSave()
	)
	
	fn setCheckedLbxList =
	(
		bTreesChecked = not bTreesChecked 
		
		c = lbxTrees.Items.Count - 1		
		for i = 0 to c where c > 0 and lbxTrees.Items.Item[i] != undefined do lbxTrees.Items.Item[i].Checked = bTreesChecked
	)
	
	fn setAliasName v =
	(			
		id = getID()
		
		if(id != 0) do
		(											
			o = execute("$'" +  Trees[id][1] + "'*") as array	
			for i in o where (getUserProp i "Alias") == Trees[id][6] do setUserProp i "Alias" v
			
			Trees[id][6] = v
			
			sessionSave()
			reloadTreesList()
		)
	)
		
	fn getRay b =
	(	
		p = b.pos
		p.z = 100.0
		
		r = ray p [0,0,-1]

		h = intersectRayScene r
			
		z = b.pos.z
				
		if(h[1] != undefined) do
		(						
			t = for i in Trees collect i[1]
			o = for i in h where findItem t (stripName i[1].name) == 0 collect i[2].pos.z
				
			if(o.count > 0) do z = o[1] + offset			
		)
		
		return z
	)
		
	tool SpeedTreePlacer
	(
		local b
		local moveObject = undefined
		local id = getID()
		local brushSize = rPlacer.spnBrushSize.value / 2.0
		local brush = Circle radius: brushSize isSelected:off wirecolor: red name: "brush" 
		local posZ
		local checkedList = getCheckedLbxListID()
		
		on mousePoint x do
		(		
			if(not altKey) then
			(																
				if(not ctrlKey) do 
				(										
					if(checkedList.count > 1) do
					(
						r = random 1 checkedList.count
						id = checkedList[r] + 1
					)
										
					b = createTree id gridPoint
					b.pos = worldPoint
					
					b.pos.z = Trees[id][2]				
					if(rPlacer.cbxPlaceOnSurface.checked == true) do b.pos.z = getRay b						
				)										
			)				
		)
		
		on freeMove do brush.pos = worldPoint
		
		on mouseMove x do
		(	
			brush.pos = worldPoint
			
			if(altKey or ctrlKey) then 
			(
				if(isValidNode b and classOf b == Box) do
				(
					try(delete b)catch()
					b = undefined
				)
			)
				
			if(b != undefined and isValidNode b) then 
			(				
				b.pos = worldPoint				
				posZ 	= Trees[id][2]				
				b.pos.z = posZ
				
				if(rPlacer.cbxPlaceOnSurface.checked == true) do 
				(					
					posZ = getRay b
					b.pos.z = posZ												
					brush.pos = b.pos
				)
			)	
			
			-- Brush place
			if(lButton and not altKey and not ctrlKey) then
			(				
				a = circlePickNode (box2 (viewPoint + 50) (viewPoint - 50))	
				
				w = worldPoint
				w.z = posZ
					
				d = for k in a where classof k == Box and (distance k.pos w) < brushSize collect k
					
				if(d.count < 2) do
				(						
					if(checkedList.count > 1) do
					(
						r = random 1 checkedList.count
						id = checkedList[r] + 1
					)
					
					b = createTree id gridPoint
					b.pos = worldPoint
					
					b.pos.z = Trees[id][2]				
					if(rPlacer.cbxPlaceOnSurface.checked == true) do b.pos.z = posZ
					
					brush.pos = b.pos
				)				
			)
			
			-- Delete
			if(altKey and lButton) then
			(								 				
				a = circlePickNode (box2 (viewPoint + 4) (viewPoint - 4))
				
				--for i in a where findString i.name Trees[id][1] != undefined and isDeleted i == false do try(delete i)catch()							
				for i in a where isDeleted i != true and isValidNode i and classOf i == Box do delete i
			)			
			
			-- Move
			if(ctrlKey and lButton and moveObject == undefined) then 
			(								
				a = circlePickNode (box2 (viewPoint + 4) (viewPoint - 4))
					
				for i in a where findString i.name Trees[id][1] != undefined do
				(
					moveObject = i														
					exit
				)
			)			
			
			if(not lButton) do
			(
				moveObject = undefined
			)

			if(moveObject != undefined) do
			(
				moveObject.pos = worldPoint
				moveObject.pos.z = Trees[id][2]					
				
				if(rPlacer.cbxPlaceOnSurface.checked == true) do moveObject.pos.z = getRay moveObject	
			)
		)		
		
		on mouseAbort x do
		(
			try(delete b)catch()
			try(delete brush) catch()
			btnPlaceTree.checked = false
		)				
	)
	
	fn getIntersect b =
	(	
		p = b.pos
		p.z = 1000000.0
		
		r = ray p [0,0,-1]

		h = intersectRayScene r
			
		z = b.pos.z
				
		if(h[1] != undefined) do
		(						
			t = for i in Trees collect i[1]
			o = for i in h where classOf i[1] != Box do return i[1].pos.z							
		)
		
		return z
	)
	
	fn brushPaint r d id =
	(	
		pos = mapScreenToCP mouse.pos
		pos.z = Trees[id][2]
				
		c = ((r / d) ^ 2) * 2
		if(c < 1.0) do c = 1
	
		m = #()		
		
		a = circlePickNode (box2 (mouse.pos + 100) (mouse.pos - 100))	
		m2 = for k in a where classof k == Box collect k.pos
			
		for i in 1 to c do 
		(	
			for k in 1 to 10 do
			(
				x = random -r r
				y = random -r r
				z = 0

				p = [x, y, z] + pos
								
				u = for ii in m where distance ii p < d collect ii
				u2 = for ii in m2 where distance ii p < d collect ii
							
				if(u.count == 0 and u2.count == 0 and distance pos p < r ) do 
				(
					--p.z = Trees[id][2]
					
					append m p	
					exit
				)
			)				
		)
		
		return m
	)
	
	fn getScreenPos ir id =
	(
		if(ir != undefined and rPlacer.cbxPlaceOnSurface.checked) do return ir.pos
		
		m = mapScreenToCP mouse.pos
		m.z = Trees[id][2]
		return m
	)
	
	fn trackRay placeObj ir id =
	(
		currentRotation = placeObj.rotation as eulerAngles
		
		if(ir != undefined and rPlacer.cbxPlaceOnSurface.checked) then
		(											
			placeObj.pos = ir.pos 
			if(rPlacer.cbxFollowDirection.checked) do placeObj.dir = ir.dir
				
			if(superClassOf placeObj != Shape) do in coordsys local rotate placeObj (eulerAngles 0 0 (random 0.0 360.0))
			
			return #continue
		)
		else
		(			
			placeObj.pos = mapScreenToCP mouse.pos
			placeObj.pos.z = Trees[id][2]
			
			placeObj.dir = [0,0,1]
		
			if(superClassOf placeObj != Shape) do in coordsys local rotate placeObj (eulerAngles 0 0 (random 0.0 360.0))
			
			return #continue
		)				
	)
	
	fn getRandomId id c = 
	(
		if(c.count > 1) do
		(
			r = random 1 c.count
			id = c[r] + 1
			
			return id
		)		
		
		return id
	)
	
	fn brushMode =
	(
		global brushSize = rPlacer.spnBrushSize.value / 2.0
		global brushDensity = rPlacer.spnDistance.value / 2.0
		global brush = Circle radius: brushSize  isSelected:off wirecolor: red name: "brush" 
		global density = Circle radius: brushDensity  isSelected:off wirecolor: yellow name: "density" 
		global radius = Text size: (units.decodeValue "100.0cm") name: "radius" wirecolor: green
		global id = getID()
		global checkedList = getCheckedLbxListID()
		global placeObj = undefined
		global isMove = false
		
		hide radius
		
		disableUI false place: true
		
		fn mouseTrackCallback msg ir obj faceNum shift ctrl alt =
		(	
			global initMousePos
			
			case msg of
			(
				#freeMove:
				(	
					initMousePos = mouse.pos					
					trackRay brush ir id
					trackRay density ir id
					trackRay radius ir id
					
					/*
					if(isMove) do
					(
						try(delete placeObj) catch()
						isMove = false
					)*/
									
					
					isMove = false
					hide radius
					
					return #continue
				)
				#mouseAbort:
				(																								
					try(delete brush) catch()
					try(delete density) catch()
					try(delete radius) catch()
					btnPlaceTree.checked = false
								
					disableUI true
					
					return #end
				)
				#mousePoint:
				(										
					if(not isMove) do
					(
						id = getRandomId id checkedList
					
						placeObj = createTree id [0, 0, 0]
						trackRay placeObj ir id
					)
										
					return #continue
				)
				#mouseMove:
				(
						
					r = rPlacer.spnBrushSize.value / 2.0
					d = rPlacer.spnDistance.value
					
					isMove = true	
					
					if(not ctrl and not shift) do
					(
						trackRay brush ir id
						trackRay density ir id
						trackRay radius ir id
																
						p = brushPaint r d id
						
						disableSceneRedraw()
						
						for i in p do
						(
							id = getRandomId id checkedList
													
							t = createTree id i 
													
							--if(rPlacer.cbxPlaceOnSurface.checked) do t.pos.z = getIntersect t
						)
						
						enableSceneRedraw()
					)
					
					if(ctrl) do
					(					
						s = (initMousePos.y - mouse.pos.y) 
						v = rPlacer.spnBrushSize.value
						
						case of
						(
							(s <= 0.0) : v = v - (units.decodeValue "25.0cm")
							default:  v = v + (units.decodeValue "25.0cm")
						)
						
						maxVal = (rPlacer.spnBrushSize.range)[2]
						minVal = rPlacer.spnDistance.value
						
						if(v <= maxVal and v >= minVal) do
						(
							rPlacer.spnBrushSize.value = v
							brush.radius = rPlacer.spnBrushSize.value / 2.0
						)

						unhide radius
						radius.text = "Brush: " + rPlacer.spnBrushSize.value as string
						o = -rPlacer.spnBrushSize.value
						radius.pos = brush.pos + [o / 20, -o / 2,0]
					)
					
					if(shift) do
					(
						s = (initMousePos.y - mouse.pos.y)
						v = rPlacer.spnDistance.value
						
						case of
						(
							(s <= 0.0) : v = v - (units.decodeValue "10.0cm")
							default:  v = v + (units.decodeValue "10.0cm")
						)
						
						maxVal = rPlacer.spnBrushSize.value
						minVal = (rPlacer.spnDistance.range)[1]
						
						if(v <= maxVal and v >= minVal) do
						(
							rPlacer.spnDistance.value = v
							density.radius = rPlacer.spnDistance.value / 2.0
						)
						
						unhide radius
						radius.text =  "Distance: " + rPlacer.spnDistance.value as string
						o = -rPlacer.spnBrushSize.value
						radius.pos = brush.pos + [o / 20, -o / 2,0]
					)				
					
					return #continue
				)									
			)
		)
				
		o = for i in geometry where i.isHidden == false and classOf i != Box collect i
		trackCallback = mouseTrack on:o trackCallBack: mouseTrackCallback
	)
	
	fn placeObject =
	(			
		global id = getID()
		global checkedList = getCheckedLbxListID()
		global placeObj = undefined
		global isMove = false
		
		disableUI false place: true
		
		fn mouseTrackCallback msg ir obj faceNum shift ctrl alt =
		(	
			case msg of
			(
				#freeMove:
				(												
					return #continue
				)
				#mouseAbort:
				(																								
					btnPlaceTree.checked = false
					
					disableUI true
								
					return #end
				)
				#mousePoint:
				(										
					id = getRandomId id checkedList
					
					placeObj = createTree id [0, 0, 0]
					trackRay placeObj ir id
					
					if(isMove) do
					(
						try(delete placeObj) catch()
						isMove = false
					)
					
					return #continue
				)
				#mouseMove:
				(	
					isMove = true	
					
					if(not alt and not ctrl) do
					(
						d = rPlacer.spnDistance.value
										
						a = circlePickNode (box2 (mouse.pos + 50) (mouse.pos - 50))	
						m2 = for k in a where classof k == Box collect k.pos
						
						s = getScreenPos ir id
						
						y = for i in m2 where distance i s < d collect i 
						
						if(y.count == 0) do
						(
							placeObj = createTree id [0, 0, 0]
							trackRay placeObj ir id 
						)
					)
					
					if(alt) do
					(
						a = circlePickNode (box2 (mouse.pos + 4) (mouse.pos - 4))
							
						for i in a where isDeleted i != true and isValidNode i and classOf i == Box do delete i
					)
					
					if(ctrl) do
					(
						a = circlePickNode (box2 (mouse.pos + 3) (mouse.pos - 3))
					
						for i in a where isDeleted i != true and isValidNode i and classOf i == Box do 
						(
							trackRay i ir id
													
							exit
						)
					)
					
					return #continue
				)									
			)
		)
				
		o = for i in geometry where i.isHidden == false and classOf i != Box collect i
		trackCallback = mouseTrack on:o trackCallBack: mouseTrackCallback
	)
	
	on lbxTrees columnClick x do
	(
		i = x.Column
			
		case i of 
		(
			0: setCheckedLbxList()  
		) 
		
		lbxTrees.Update()
		lbxTrees.Refresh()
	)
	
	on rdoExportFor changed s do
	(
		try(fileProperties.addProperty #custom "Used Engine" (rdoExportFor.state)) catch()	
	)
	
	fn pickTree =
	(	
		/* 1 - TreeName; 2 - Z pos; 3 - Color; 4 - Scale; 5 - Size; 6 - Alias */
		
		fn boxFilter o = (classOf o == box)
		
		o = pickObject count: 1 select: true filter: boxFilter message: "Please pick only box (Not mesh or poly)!"
		
		if(o == undefined) do return false
		
		Tree = #()
		n = stripName o.name
		a = getUserProp o "Alias"
		if(a == undefined) do setUserProp o "Alias" n
		
		Tree[1] = n
		Tree[2] = o.pos.z
		Tree[3] = o.wirecolor
		Tree[4] = o.scale.z
		Tree[5] = try(o.width)catch(1.0)
		Tree[6] = (if(a != undefined) then a else n) + " (pick" + (Trees.count + 1) as string + ")"
		
		append Trees Tree
						
		sessionSave()
		
		reloadTreesList()
		
		SelectedColorLbxList (Trees.count - 1)
	)
	
	fn addTree t =
	(
		/* 1 - TreeName; 2 - Z pos; 3 - Color; 4 - Scale; 5 - Size; 6 - Alias */
		
		c = random black white
		Tree  = #(t, 0.0, c, 1.0, (units.decodeValue "100.0cm"), t)
		
		append Trees Tree
		
		CreateDummy t c
		
		sessionSave()
		
		reloadTreesList()
		
		SelectedColorLbxList (Trees.count - 1)		
	)
	
	fn getTreesNames =
	(
		s = rPlacer.rdoExportFor.state
		f = #()
		t = szSpeedTreeFolder
		
		case s of
		(
			2:
			(
				d = getDirectories (t + @"\*")
				append d t
				
				for i in d do 
				(
					a = getFiles (i + @"\*.uasset")
										
					for ii in a do
					(	
						n = filenameFromPath ii
						z = findString n "_Atlas_"
						
						if (z != undefined and z > 1) do appendIfUnique f (substring n 1 (z - 1))
					)
				)
			)
			default: 
			(
				f = getFiles (t + @"\*.srt")			
				f = for i in f collect filenameFromPath i				
			)
		)
		
		return f
	)
	
	on btnAddReferenceTree pressed do
	(
		t = szSpeedTreeFolder
					
		t = getTreesNames()
		
		p = btnAddReferenceTree.pos
		p.y += 27
		
		ex = "rcmenu rcTreesAdd \n(\n"
		ex += "fn addTree t = (Trees[1][1] = t) \n"
		
		tmpTrees = for i in Trees collect i[1]		
		
		cnt = 0
		
		for i in 1 to t.count where findItem tmpTrees t[i] == 0 do
		(			
			ex += "menuItem rcAdd" + i as string +  " \"" + t[i] + "\"\n" 
			ex += "on rcAdd" + i as string + " picked do rPlacer.addTree \"" + t[i] + "\"\n"	

			cnt += 1
		)
		
		ex += "fn sepShow = " + (cnt != 0) as string + "\n"
		ex += "separator sep1 filter: sepShow\n"	
		ex += "menuItem rcPick \"Pick From Scene\" \n"
		ex += "on rcPick picked do rPlacer.pickTree()"
		ex += "\n )\n popUpMenu rcTreesAdd rollout: rPlacer pos:" + p as string + "\n"
		
		execute ex
	
	)
	
	fn getPreview id show: false=
	(
		if(Trees.count == 0) do return false
		
		i = rdoExportFor.state
		
		p = szPreviewsPath[i]
		
		f = p + (getFileNameFile Trees[id][1]) + ".png"
		
		
		btmPreview.images = undefined
		if(f != undefined and doesFileExist f) do 
		(
			b = openBitMap f
			btmPreview.images = #(b, undefined, 1,1,1,1,1 )		
			
			if(show) do display b
		)
	)
		
	on rdoMode changed a do
	(
		placeMode()
	)
	
	on tmrPreview tick do 
	(
		id = getID()
		
		getPreview id
		
		tmrPreview.active = false
	)
	
	on btmPreview pressed do 
	(
		id = getID()
		
		getPreview id	show: true
	)
	
	on lbxTrees MouseClick a do
	(				
		/*h = lbxTrees.HitTest (dotNetObject "System.Drawing.Point" a.x a.y)
		id = h.item.index + 1*/

		SelectedColorLbxList 0
			
		id = getID()
				
		getParams id	

		tmrPreview.active = true
	)
	
	on edtAliasName entered v do
	(
		setAliasName v
	)
	
	on btnDeleteReferenceTree pressed do
	(	
		if(id == 0) do return false
		
		id = rPlacer.getID()
		
		o = execute("$'" +  Trees[id][1] + "'*") as array
		o = findByAlias o Trees[id][6]		
		
		fn deleteDialog p o =
		(
			global iCnt = o
			global iState = 0
			
			
			
			rollout rDeleteTree "Delete Tree" 
			(
				label lblStat "" align: #left height: 40
				group "Delete:" 
				(
					radiobuttons rdoDelete "" labels:#("Tree from list", "Tree from scene", "Tree from list and scene") default:1  align: #left
				)
				
				button btnOk "OK" across: 2 width: 70 height: 25 offset: [0, 7]
				button btnCancel "CANCEL" width: 70 height: 25 offset: [0, 7]				
				
				on rDeleteTree open do
				(					
					local id = rPlacer.getID()
					lblStat.caption = "Name:\t" + Trees[id][1] + "\nAlias:\t" + Trees[id][6] + "\nCount:\t" + iCnt as string
				)
				
				on btnOk pressed do
				(					
					iState = rdoDelete.state
					destroyDialog rDeleteTree
				)
				
				on btnCancel pressed do
				(
					iState = 0
					destroyDialog rDeleteTree
				)
			)

			createDialog rDeleteTree 250 170 modal: true pos: p
			
			return iState
		)
				
		p = rSpeedTreePlacer.pos + [25, 400]
		
		q = deleteDialog p o.count
		
		if(q == 0) do return false
		
		if(q == 3 or q == 2) do
		(									
			undoName = "Delete " + Trees[id][6]
			undo undoName on try(delete o) catch()					
			
			clearSelection()			
		)
		
		if(q == 1 or q == 3) do
		(
			try
			(						
				deleteItem Trees id
					
				edtAliasName.text = ""
					
				sessionSave()
					
				reloadTreesList()		
			)
			catch()
		)
	)
	
	on btnSelectReferenceTree pressed do
	(
		id = getID()
		if(id != 0) do
		(
			s = #()
			
			o = execute("$'" +  Trees[id][1] + "'*") as array	
					
			s = findByAlias o Trees[id][6]
						
			clearSelection()
			try(select s) catch()
		)
	)
	
	on btnDublicateReferenceTree pressed do
	(
		id = getID()

		if(id != 0 and Trees[id][1] != undefined) do 
		(
			insertItem (copy Trees[id] #nomap) Trees (id + 1)
			Trees[id + 1][6] = Trees[id + 1][1] + " (copy)"
			
			sessionSave()
			reloadTreesList()
			SelectedColorLbxList (id)
			getParams (id + 1)
		)			
	)
	
	on btnPlaceTree changed v do
	(	
		if(v != true) do return false
		
		if(getID() == 0) do
		(
			btnPlaceTree.checked = false
			messageBox "Please add the Tree!" title: "Warning!"
			return false
		)
		
		SelectedColorLbxList 0
		--reloadTreesList()
		
		--startTool SpeedTreePlacer	
		
		m = rdoMode.state
		case m of 
		(
			2: brushMode()
			default: 	placeObject()				
		)
	)
	
	on rPlacer open do
	(						
		rPlacer.disableUI false
		
		x = (useSettings "x" "float" 0) as float
		y = (useSettings "y" "float" 0) as float
	
		try(rSpeedTreePlacer.pos = [x, y]) catch()
		
		i = fileProperties.findProperty #custom "SpeedTree Project"
		i2 = fileProperties.findProperty #custom "Used Engine"
		
		if(i2 != 0) do
		(
			rdoExportFor.state = fileProperties.getPropertyValue #custom i2
		)
		
		if(i != 0) do 
		(
			szSpeedTreeFolder = fileProperties.getPropertyValue #custom i
			edtBrowse.text = szSpeedTreeFolder
			rPlacer.disableUI true
		)
						
		initDotNet()
				
		sessionLoad()
				
		reloadTreesList()
	
		id = getID()
		
		getParams id				
	)
	
	on rPlacer close do
	(
		saveWindowPos()
	)
	
	on rPlacer moved p do
	(
		iWindowPos = p
	)
	
	on spnScale changed v do setParams()
	on spnSize changed v do setParams()
	on spnBrushSize changed v do setParams()
	on spnZ changed v do setParams()
	
	on cpColor changed v do 
	(			
		tmrColor.active = false
		tmrColor.active = true			
	)
	
	on tmrColor tick do
	(
		id = getID()
		
		if(id != 0) do
		(											
			o = execute("$'" +  Trees[id][1] + "'*") as array				
			z = findByAlias o Trees[id][6]
			z.wirecolor = cpColor.color
			
			Trees[id][3] = cpColor.color
			
			tmrColor.active = false
			
			sessionSave()
			reloadTreesList()
		)
	)
	
	fn browseProject =
	(
		edtBrowse.text = szSpeedTreeFolder
		rPlacer.disableUI true
		useSettings "FOLDER" szSpeedTreeFolder 1
		try(fileProperties.addProperty #custom "SpeedTree Project" szSpeedTreeFolder) catch()	
	)
	
	on btnBrowse pressed do
	(
		saveWindowPos()
		
		szInitalDir = useSettings "FOLDER" "string" 0
		
		t = szSpeedTreeFolder
		szSpeedTreeFolder = getSavePath caption:"Browse" initialDir: szInitalDir
				
		if(szSpeedTreeFolder != undefined and szSpeedTreeFolder != "") then
		(																			
			if(t != szSpeedTreeFolder) do 
			(
				initDotNet()
				getParams 0
				
				tmrPreview.active = true
				Trees = #()
			)
			browseProject()									
		)	
		else if(szSpeedTreeFolder == undefined and t != undefined) then		
		(
			szSpeedTreeFolder = t
		)
		
		return false
	)
		
)

global prevSelected = #()

global selectonChanged = #()

fn fwdScatterSelect =
(
	rScatter.spnObjectsInRow.enabled = false
	rScatter.btnScatter.enabled = false
		
	if(superClassOf selection[1] == shape or classOf selection[1] == Editable_Poly) do
	(
		rScatter.btnScatter.enabled = true
		hPickedShape = selection[1]
	)
	
	if(selection.count == 2) do
	(
		s = for i in selection where classOf i == Box or classOf i == Editable_Poly collect i
		
		if(s.count == 2) do rScatter.spnObjectsInRow.enabled = true
		
		if(s[1] != prevSelected or s[2] != prevSelected[2]) do 
		(
			objectsInRow = #()
			rScatter.spnObjectsInRow.value = 0
		)
		
		prevSelected = s
	)
)

rollout rScatter "Scatter"
(	
	global scatteredObject = #()
	global scatteredPos = #()
	
	group "Arrange Trees Between Two Selected Objects"
	(
		spinner spnObjectsInRow "Trees Count:" range:[0,99999,0]  fieldWidth: 40 align: #left enabled: false type: #integer
	)
	group "Surface Scatter"
	(					
		dropdownlist ddlScatterMethod "Scatter Method:" width: 80 align: #left items: #("Fast", "Accurate") across: 2
		label lblInfo "Usefull for Trees in big square\narea. When area reached\nautomatically terminated." align: #left offset: [-35, 0] height: 60 width: 155 style_sunkenedge:true
		
		spinner spnScatterObjects "Count:" range:[0,99999,500]  fieldWidth: 40 align: #left type: #integer across: 3
		spinner spnScatterDistance "Dist:" range:[0.0,99999.0,1.0] type: #worldunits align: #left offset:[10, 0] scale: 0.1
		spinner spnScatterOffset "Offset:" range:[0.0,99999.0,0.2] type: #worldunits align: #left scale: 0.1
		--checkbutton btnCreateShape "Create Area"  width:100 height:25	across: 2
		button btnScatter "Scatter" width:100 height:25 enabled: false
	)

	on ddlScatterMethod selected x do
	(
		case x of
		(
			1: lblInfo.caption = "Usefull for Trees in big square\narea. When area reached\nautomatically terminated."
			2: lblInfo.caption  = "Usefull for Bushes in small or\ncurved area. Very slow method.\nDo not use extremal count\nparameter (Max: 1200)."
		)
	)
	
	fn displayText =
	(				
		if(selection.count < 3000 and selectonChanged != selection as array) do
		(
			displayTextNames = #()
			displayTextColors = #()
			displayTextCount = #()
						
			for i in selection where i != undefined and (classOf i == Box or classOf i == Editable_Poly) do
			(
				a = getUserProp i "Alias"
								
				if(a != undefined) do
				(
					appendIfUnique displayTextNames a
									
					w = findItem displayTextNames a
					
					if(w != 0) then
					(
						displayTextColors[w] = i.wirecolor
						if(displayTextCount[w] == undefined) do displayTextCount[w] = 0
						displayTextCount[w] += 1
					)
				)		
			)

			yRow = gw.getWinSizeY() / 4
				
			for i in 1 to displayTextNames.count do
			(			
				if(i == 1) do gw.wText ([10,yRow - 15,0]) "Selected SpeedTree Info:" color: white
	
				gw.wText ([20,yRow += 15,0]) (i as string + ". " + displayTextNames[i] + " : " + displayTextCount[i] as string) color: displayTextColors[i]
				
				if(selection.count == 1 and displayTextNames.count == 1) do
				(
					gw.wText ([20,yRow += 25,0]) ("Scale:   " + selection[1].scale.z as string) color: yellow
					try(gw.wText ([20,yRow += 15,0]) ("Size:   " + selection[1].width as string) color: yellow) catch()
					gw.wText ([20,yRow += 15,0]) ("Rotate:   " + (inverse selection[1].rotation as eulerAngles).z as string) color: yellow
					gw.wText ([20,yRow += 15,0]) ("Z:   " + selection[1].pos.z as string) color: yellow
				)
			)
			
			gw.enlargeUpdateRect #whole
			gw.updateScreen()				
		)
	
		
		selectonChanged = selection
	)

	
	fn scatterTrees a id d =
	(
		fn fastMethod a id = 
		(	
			scatteredPos = #()
			scatteredObject = #()
			listID = #()
			areaRich = 0
			
			disableSceneRedraw()
				
			z = rPlacer.getCheckedLbxListID()
			
			progressStart "Scattering Trees..."
			escapeEnable
			
			local id = id
			local a = a
			
			for i in 1 to spnScatterObjects.value do
			(		
				if(z.count > 1) do
				(
					r = random 1 z.count
					id = z[r] + 1
				)
				
				for ii in 1 to 200 do
				(
					p = [(random a.min.x a.max.x), (random a.min.y a.max.y), (a.max.z) + 1.0]
					
					r = ray p [0,0,-1]
				
					s = intersectRay a r
								
					p.z -= 1.0
					
					if(s != undefined) do
					(						
						bCreate = true
						
						v = spnScatterDistance.value
						
						
						for iii in scatteredPos where distance iii p < v do bCreate = false
										
						if(bCreate == true) do
						(															
							append listID id
							append scatteredPos p
							exit
						)
					)
					
					if(ii == 200) do areaRich += 1
				)
				
				
				if(areaRich > 16) do
				(
					progressUpdate 100.0
					exit
				)
				
				progressUpdate (100.0 * i / spnScatterObjects.value)
				if(getProgressCancel() == true)do exit	
			)
			
					
			for i in 1 to scatteredPos.count do
			(		
				id = listID[i]			
				p = scatteredPos[i]
				p.z += spnScatterOffset.value
				b = createTree id p
				append scatteredObject b
			)
			
			progressEnd()
		
			select scatteredObject
			
			enableSceneRedraw()			
		)
							
		fn	accurateMethod a id=
		(
			scatteredPos = #()
			scatteredObject = #()
			listID = #()
			areaRich = 0
			
			disableSceneRedraw()
				
			z = rPlacer.getCheckedLbxListID()
			
			progressStart "Scattering Trees..."
			escapeEnable
			
			-- Start from 100 points
			local id = id
			local a = a
			
			for ii in 1 to 100 do
			(
				p = [(random a.min.x a.max.x), (random a.min.y a.max.y), (a.max.z) + 1.0]
				
				r = ray p [0,0,-1]
			
				s = intersectRay a r
				
				p.z -= 1 
				
				if(s != undefined) do 
				(										
					append listID id
					append scatteredPos p
				)
			)
					
			if(scatteredPos[1]) == undefined do return false
						
			for i in 1 to spnScatterObjects.value do
			(		
				if(z.count > 1) do
				(
					r = random 1 z.count
					id = z[r] + 1
				)
							
				local iRadius = spnScatterDistance.value
								
				for ii in 1 to scatteredPos.count do 
				(
					j = random 0.0 360.0
									
					m = scatteredPos[ii]
									
					x = iRadius * sin(j) + m.x
					y = iRadius * cos(j) + m.y
					
					p = [x, y, (a.pos.z) + 1.0]
										
					r = ray p [0,0,-1]
				
					s = intersectRay a r
					
					p.z -= 1 					
					
					v = spnScatterDistance.value
					
					if(s != undefined) do
					(								
						bCreate = true
						
						v = spnScatterDistance.value
											
						for iii in scatteredPos where distance iii p < iRadius do bCreate = false
										
						if(bCreate == true) do
						(						
							append listID id
							append scatteredPos p
							exit
						)
					)
					
					if(ii == scatteredPos.count) do areaRich += 1
				)
								
				if(areaRich > 50) do
				(
					progressUpdate 100.0
					exit
				)
				
				progressUpdate (100.0 * i / spnScatterObjects.value)
				if(getProgressCancel() == true)do exit	
			)
					
			for i in 1 to scatteredPos.count do
			(		
				id = listID[i]			
				p = scatteredPos[i]
				p.z += spnScatterOffset.value
				b = createTree id p
				append scatteredObject b
			)
			
			progressEnd()
		
			select scatteredObject
			
			enableSceneRedraw()
		)
		
		
		case ddlScatterMethod.selection of
		(
			1: fastMethod a id
			2: accurateMethod a id
		)
				
		if(d == true) do try(delete a) catch()
	)
	
	fn createMesh s =
	(		
		s = copy s
		
		addModifier s (Extrude amount: -0.0)
		addModifier s (Cap_Holes ())
		addModifier s (Vertex_Weld())
				
		convertToPoly s	
		s.pivot = s.center
			
		n = polyOp.getNumFaces s
		
		if(n == 0) do 
		(
			try(delete s) catch()
			
			messageBox "Warning area has self collision!" title: "Warintng!"
					
			return undefined
		)
				
		polyop.CollapseDeadStructs s
			
		n = polyop.getFaceNormal s 1
			
		polyop.deleteFaces s (if(n == [0,0,-1]) then #{1} else#{2})
		polyop.CollapseDeadStructs s
			
		s.SetSelection #Face #{1}	
		select s
		

		max hide selection 
			
		return s
	)
	
	on spnObjectsInRow changed v do
	(
		if(selection.count < 2) do return false
		
		startPos = selection[1].pos
		endPos = selection[2].pos
		
		distLen = endPos - startPos
		
		id = rPlacer.getID()
				
		for i in objectsInRow do try(delete i) catch()
		objectsInRow = #()
		
		for i in 1 to v do append objectsInRow (createTree id [0, 0, 0])	
			
		for j in 1 to objectsInRow.count do objectsInRow[j].pos = (startPos + (distLen * (((j as float)/(objectsInRow.count + 1)))))
	
	)
	
	on btnCreateShape changed v do
	(	
		try(stopTool createLine) catch()
		
		if(v == false) do return false
					
		fn lineCallback s =
		(
			s.steps = 0
			s.optimize  = false
			s.adaptive = false
		)
		
		n = startObjectCreation line returnNewNodes: true newNodeCallback: lineCallback
 
		for i in n do
		(
			convertTo i SplineShape
			close i 1
			
			n = numKnots i
			
			if(n < 3) do try(delete i; exit) catch()	
			
			z = i.max.z
			
			for ii in 1 to n do 
			(
				p = getKnotPoint i 1 ii
				p.z = z
				setKnotPoint i 1 ii p
				setKnotType i 1 ii #corner 
			)
					
			updateShape i	

			i.pivot = i.center
		)

		
		btnCreateShape.checked = false
	)
	
	on btnScatter pressed do
	(
		id = rPlacer.getID()
		if(id == 0) do
		(
			messageBox "Please add the Tree!" title: "Warning!"
			return false
		)
				
		if(superClassOf hPickedShape == Shape) then
		(
			s = createMesh hPickedShape
			scatterTrees s id true
		)
		else if (classOf hPickedShape == Editable_Poly) do
		(
			scatterTrees hPickedShape id false
		)			
	)
	
	on rScatter open do
	(
		fwdScatterSelect()
		
		RegisterRedrawViewsCallback displayText
		
		callbacks.removescripts id:#fwdScatterSelect
		callbacks.addScript #selectionSetChanged "fwdScatterSelect()" id:#fwdScatterSelect persistent:false	
	)
	
	on rScatter close do
	(
		unRegisterRedrawViewsCallback displayText
	)
	
	on rScatter rolledUp x do
	(		
		rPlacer.lbxTrees.Update()
		rPlacer.lbxTrees.Refresh()
	)
)

rollout rDrop "Drop Trees"
(
	button btnDropTrees "Drop Selected Trees" height: 25 width: 150
	
	fn getRay b =
	(	
		p = b.pos
				
		r = ray p [0,0,-1]

		h = intersectRayScene r
			
		z = b.pos.z
			
		
		if(h[1] != undefined) then
		(						
			/*t = for i in Trees collect i[1]
			o = for i in h where findItem t (stripName i[1].name) == 0 collect i[2].pos.z*/
			
			o = for i in h where classOf i != Box collect i[2].pos.z
				
			if(o.count > 0) do z = o[1] 		
		)
		
		return z
	)
	
	
	on btnDropTrees pressed do
	(
		dropTrees = for i in selection where classOf i == Box collect i
			
		progressStart "Drop Trees..."
		escapeEnable
		
		disableSceneRedraw()
		
		bWarning = false
		
		for i in 1 to dropTrees.count do
		(
			z1 = dropTrees[i].pos.z
			z2 = getRay dropTrees[i]
			if(z1 == z2) do bWarning = true
			dropTrees[i].pos.z = z2
			
			progressUpdate (100.0 * i / dropTrees.count)
			if(getProgressCancel() == true)do exit	
		)
		
		enableSceneRedraw()
		enableSceneRedraw()
		enableSceneRedraw()
		forceCompleteRedraw()
		
		if(bWarning) do messageBox "Some trees not dropped!" title: "Warning!"
		
		progressEnd()
	)
)

rollout rTools "Tools"
(
	group "Session"
	(
		button btnExportSession "Save" across: 2
		button btnImportSession "Load"
	)
	group "Set Alias For Selected"
	(
		edittext edtSetAlias "" width: 200 across: 2 align: #left
		button btnSetAlias "Set" align: #right offset: [0, -3]
	)
	
	fn setAlias a = 
	(
		if(a.count > 0) then
		(
			s = for i in selection where classOf i == Box collect i
				
			if(s.count == 0) then 
			(
				messageBox "Please select trees!" title: "Warning!"
			)
			else
			(
				for i in s do setUserProp i "Alias" a
				edtSetAlias.text = ""
				messageBox ("Alias " + a + " set for " + s.count as string + " trees.") title: "Success!"
			)
		)
		else
		(
			messageBox "Please use correct alias!" title: "Warning!"
		)
	)
	
	fn sessionExport =
	(
		t = szSpeedTreeFolder
				
		if(t == undefined or t == "") do
		(
			messageBox "Please Browse project!" title: "Warning"
			
			return false
		)
		
		
		d = getLocalTime()
		d = t + "\\" + (SelectedDir t) + "_" + d[4] as string + "." + d[2] as string + "." + d[1] as string
		
		f = getSaveFileName filename: d caption: "Save Session" types: "Trees Session (*.ts)|*.ts"
				
		if(f == undefined) do return false
		
		delIniSetting f "TREES"
		
		for i in Trees do
		(
			s = ""
			for z in 1 to 6 do s += (i[z] as string + "|")
			setINISetting f "TREES" s "true"	
		)
		
		setINISetting f "MAIN" "PATH" t
	)
	
	fn sessionImport =
	(				
		f = getOpenFileName filename: "" caption: "Open Session" types: "Trees Session (*.ts)|*.ts"
		
		if(f == undefined) do return false
		
		t = getINISetting f "TREES"
		
		Trees = #()	
		
		for i in t do
		(
			s = filterString i "|"
			
			if(s == undefined) do continue
			
			Tree = #()
			
			c = filterString s[3] "()color "
			c = for p in c collect p as float
			
			Tree[1] = s[1] as string
			Tree[2] = s[2] as float
			Tree[3] = [c[1], c[2], c[3]] as color
			Tree[4] = s[4] as float
			Tree[5] = s[5] as float
			Tree[6] = s[6] as string
			
			append Trees Tree
			
			CreateDummy Tree[1] Tree[3] 
		)
		
		
		p = getINISetting f "MAIN" "PATH"
		
		szSpeedTreeFolder = p
		
		rPlacer.browseProject()
		
		rPlacer.sessionSave()
		rPlacer.reloadTreesList()
	)
	
	on btnExportSession pressed do sessionExport()
	on btnImportSession pressed do sessionImport()	
	
	on btnSetAlias pressed do setAlias edtSetAlias.text
	
	on rAbout rolledUp x do
	(		
		rPlacer.lbxTrees.Update()
		rPlacer.lbxTrees.Refresh()
	)
)

rollout rAbout "About" 
(	
	label lblName "" 
	label lblVer "" 
	
	label lblAuthor "" height: 30
	label lblCopy ""  height: 30
	button btnHelp "Help" enabled: false
	
	fn getHelp run: false =
	(
		s = getThisScriptFilename()
		i = getScriptInfo s
		szHelp = (getFilenamePath s) + i[7]
		if(i[7] != "" and doesFileExist szHelp) do btnHelp.enabled = true
			
		if(run) do ShellLaunch szHelp ""
	)
	
	on btnHelp pressed do getHelp run: true
				
	on rAbout open do
	(		
		i = getScriptInfo (getThisScriptFilename())
			
		lblName.caption = i[1]
		lblAuthor.caption = i[2]
		lblVer.caption = i[3]
		lblCopy.caption = i[6]
		
		getHelp()
	)

	on rAbout rolledUp x do
	(		
		rPlacer.lbxTrees.Update()
		rPlacer.lbxTrees.Refresh()
	)
)

addRollout rPlacer rSpeedTreePlacer rolledUp:false 
addRollout rScatter rSpeedTreePlacer rolledUp:true
addRollout rDrop rSpeedTreePlacer rolledUp:true
addRollout rTools rSpeedTreePlacer rolledUp:true 
addRollout rAbout rSpeedTreePlacer rolledUp:true 
