/*  
[INFO] 

NAME = SLV_Quick Attach
VERSION = 1.0.0
AUTHOR = MastaMan
DEV = VISCO
HELP = 

[1.0.0]

* First release =

[ABOUT]

Fast attach objects.=

[TEST]

[SCRIPT]
*/	

global _FORM_TOUCHED = false
global _rQuickAttach

try(closeRolloutFloater f_SLV_QUICK_ATTACH) catch()
global f_SLV_QUICK_ATTACH = newRolloutFloater "Quick Attach" 250 200

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

fn useSettings k p w =
(
	/*
		useSettings "key" "value/int/float/bool/bool_not" "r/w" 
	*/
	
	u = sysInfo.username
	d = getFilenamePath  (getThisScriptFilename())
	n = filenameFromPath (getThisScriptFilename())			
	settingsFile = d + @"ini\" + u + "_" + n + ".ini"
		
	v = maxVersion()
	v = 2000 + ((v[1] / 1000) - 2)
	
	t = v as string
	
	case w of
	(
		"r":
		(
			s = getINISetting settingsFile t k
			case p of
			(
				"int": return s as integer
				"float": return s as float
				"bool": if s == "true" or s.count < 1 then true else false
				"bool_not": if s == "true" then true else false
				
				default: return s
			)
		)
		default: return setINISetting settingsFile t k (p as string)
	)
)	

fn checkVray =
(
	for r in RendererClass.classes where matchpattern (r as string) pattern:"*V_Ray_Adv*" do return true		
	return false	
)

rollout  _rQuickAttach "" 
(	
	group "Attach By:" (
		radiobuttons  rdoAttachBy "" labels: #("Selected Objects", "Selected Objects Color", "Name Start From") columns: 1 align: #left
		edittext edtPartOfName "" enabled: false
	)
	
	button btnAttach "Quick Attach" width: 220 height: 35 offset: [0, 10]
	
	fn freezeUi =
	(
		source = ""
		source += "using System;\n"
		source += "using System.Runtime.InteropServices;\n"
		source += "class WindowsGhosting\n"
		source += "{\n"
		source += " [DllImport(\"user32.dll\")]\n"
		source += " public static extern void DisableProcessWindowsGhosting();\n"
		source += "}\n"
	  
		csharpProvider = dotnetobject "Microsoft.CSharp.CSharpCodeProvider"
		compilerParams = dotnetobject "System.CodeDom.Compiler.CompilerParameters"
	  
		compilerParams.GenerateInMemory = on
		compilerResults = csharpProvider.CompileAssemblyFromSource compilerParams #(source)
	  
		assembly = compilerResults.CompiledAssembly
		windowsGhosting = assembly.CreateInstance "WindowsGhosting"
		windowsGhosting.DisableProcessWindowsGhosting()
	)

	fn boost = if (((maxVersion())[1] / 1000) >= 13) do windows.processPostedMessages() 
	
	fn quickAttach objs = (
		
		freezeUi()		
		clearSelection()
		cnt = 0
		
		tmp = #()
		chunk = 300
		
		t = Editable_Mesh()	
		convertTo t Editable_Poly
		t.name = objs[1].name
			
		append tmp t
				
		progressStart "Quick Attach"
		
		for i in 1 to objs.count do (
			cnt += 1
			
			if(cnt >= chunk) do (
				cnt = 1
				t = Editable_Mesh()
				convertTo t Editable_Poly
				t.name = objs[i].name
				append tmp t
				gc()
				boost()
			)
			
			if (SuperClassOf objs[i] == GeometryClass) and (IsValidNode objs[i]) do (
				polyop.attach  t objs[i] 
				
				boost()
				if (keyboard.EscPressed) do (
					q = queryBox "Do you want to stop Quick Attach?" title: "Confirm"
					progressEnd()
					if(q) do return t
				)
			) 
			
			progressUpdate (100 * i / objs.count)
		)
		
		progressEnd()
		
		progressStart "Quick Attach"
			
		if(tmp.count != 0) do (
			t = Editable_Mesh()	
			convertTo t Editable_Poly
			t.name = tmp[1].name
			
			for i in 1 to tmp.count do (
				polyop.attach  t tmp[i] 				
				progressUpdate (100 * i / tmp.count)
			)
			
			gc()
		)
		
		progressEnd()
			
		select t
		t.pivot = t.center
		free tmp
		free objs
				
		return t
	)
	
	fn getByColor = (
		clr = #()
		
		sel = selection as array
			
		for g in sel do appendIfUnique clr g.wirecolor
		
		objs = #()
		for g in geometry do (
			c = findItem clr g.wirecolor
			if(c == 0) do continue
			if(objs[c] == undefined) do objs[c] = #()
			append objs[c] g
		)
		
		return objs
	)
	
	fn getByNameStart = (
		return for g in geometry where matchPattern g.name pattern: (edtPartOfName.text + "*") collect g
	)
	
	on rdoAttachBy changed  s do (
		edtPartOfName.enabled = false
		if(s == 3) do edtPartOfName.enabled = true
	)
	
	on btnAttach pressed do (
		objs  = #()
		cnt = 0
		
		undo "Quick Attach" on (
			case rdoAttachBy.state of (
				1: (
					objs = selection as array
					
					if(objs.count == 0) do return messageBox "No objects selected!" title: "Warning!"
					
					q = queryBox ("Do you want to attach " + objs.count as string + " selected objects?") title: "Confirm?"
					if(not q) do return false
					
					t = quickAttach objs
				)
				2: (
					objs = selection as array
					
					if(objs.count == 0) do (
						messageBox "Please selecte objects!" title: "Warning!"
						return #()
					)
					
					objs = getByColor()	
					
					if(objs.count == 0) do return false --messageBox "No objects in scene!" title: "Warning!"

					q = queryBox ("Do you want to attach by " + objs.count as string + " colors?") title: "Confirm?"
					if(not q) do return false
					
					for o in objs do ( 
						t = quickAttach o
					)
				)
				3: (
					objs = getByNameStart()	
					
					if(objs.count == 0) do return messageBox "No objects name matched!" title: "Warning!"
					
					q = queryBox ("Do you want to attach " + objs.count as string + " objects with matched part of name?") title: "Confirm?"
					if(not q) do return false
					
					t = quickAttach objs
				)
			)
		)
		
		if(objs.count != 0) do messageBox "Attach completed!" title: "Success!"
	)
)

rollout _rAbout "About" 
(
	label lblName "" 
	label lblVer "" 
	
	label lblAuthor "" height: 30
	label lblCopy ""  height: 30
	
	on _rAbout open do
	(		
		i = getScriptInfo (getThisScriptFilename())
			
		lblName.caption = i[1]
		lblAuthor.caption = i[2]
		lblVer.caption = i[3]
		lblCopy.caption = i[6]
	)
)



addRollout _rQuickAttach f_SLV_QUICK_ATTACH rolledUp:false border: false
addRollout _rAbout f_SLV_QUICK_ATTACH rolledUp:true 