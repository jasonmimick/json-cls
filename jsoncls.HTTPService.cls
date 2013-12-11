Class jsoncls.HTTPService Extends %CSP.REST
{
XData UrlMap 
{
  <Routes>
    <Route Url="/:className" Method="POST" Call="ConvertJSONtoCLS" />
  </Routes>
}

Parameter ActionHeader = "X_HTTP_ACTION";

Parameter DebugHeader = "X_HTTP_DEBUG";

Parameter FireForgetHeader= "X_HTTP_DONOT_FIREANDFORGET";

Parameter SessionIdHeader = "X_HTTP_SESSION";
ClassMethod dbg() [ CodeMode = expression ] 
{
  $get(^||debug)
}

ClassMethod debug(message... as %String) {
  return:..dbg()
  for i=1:1:message {
    write message(i)
  }
  write !
}

ClassMethod ConvertJSONtoCLS(className As %String) As %Status
{
  try {
    set ^||debug=($get(%request.CgiEnvs(..#DebugHeader),0)'=0)
	set ^||action=$get(%request.CgiEnvs(..#ActionHeader),"")
	set ^||fireForget=($get(%request.CgiEnvs(..#FireForgetHeader),0)'=0)
    do ..debug("json2cls DEBUG ON",$c(13,10),"className=",className," Content-Size=",%request.Content.Size)
    set jStream=%request.Content
    do ##class(jsoncls.Generator).Generate(className,jStream)
    set package=$piece(className,".",1,$length(className,".")-1)
    do ..debug("Package=",package)
    set flags="ck-d"
    set:..dbg() flags="ckd"
    do $system.OBJ.CompilePackage(package,"ck-d")
    set sc=##class(%Compiler.UDL.TextServices).GetTextAsStream(,className,.clsStream)
    if ($$$ISERR(sc) ) {
      return sc
    }
    do clsStream.OutputToDevice()
    return $$$OK
  } catch error {
     do error.OutputToDevice()
     write !
     return error.AsStatus()
  }
}

Parameter CSPAPP = "/jsoncls";

/// Dummy method - used to automagically create a CSP app to host
/// this service
ClassMethod install() [ codemode = objectgenerator ]
{
	set cspapp=..#CSPAPP
        set currentNamespace=$namespace
        set $namespace="%SYS"
	set appExists = ##class(Security.Applications).Exists(cspapp,.app,.status)
	if ( appExists ) {
		goto BootDone
	}
	set properties("AutheEnabled")=8224
	set properties("DispatchClass")=%class.Name
	set properties("Description")="REST endpoint for json-cls see: http://github.com/jasonmimick/json-cls"
	set properties("NameSpace")=currentNamespace
	set properties("Name")=cspapp
	set status=##class(Security.Applications).Create(cspapp,.properties)
        set $namespace=currentNamespace
	return:$$$ISERR(status) status
	
BootDone
	do %code.WriteLine(" // This is a dummy - used for compile-time side-effects")
	
	do %code.WriteLine(" Quit")
    quit $$$OK
}

}


