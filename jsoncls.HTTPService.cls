Class jsoncls.HTTPService Extends %CSP.REST
{
XData UrlMap 
{
  <Routes>
    <Route Url="/getErrors" Method="GET" Call="getErrors" />
    <Route Url="/clearErrors" Method="GET" Call="clearErrors" />
    <Route Url="/:className" Method="POST" Call="post" />
  </Routes>
}

Parameter ActionHeader = "HTTP_X_COSMIC_ACTION";

Parameter DebugHeader = "HTTP_X_COSMIC_DEBUG";

Parameter FireForgetHeader= "HTTP_X_COSMIC_DONOT_FIREANDFORGET";

Parameter SessionIdHeader = "HTTP_X_COSMIC_SESSION";
Parameter SessionIdHeaderOut = "X_COSMIC_SESSION";

Parameter NamespaceHeader = "HTTP_X_COSMIC_NAMESPACE";

ClassMethod dbg() [ CodeMode = expression ] 
{
  '$get(^||debug,0)
}

ClassMethod debug(message... as %String) {
  return:..dbg()
  for i=1:1:message {
    write message(i)
  }
  write !
}

ClassMethod ex(message... as %String) {
  set msg=""
  for i=1:1:message { set msg=msg_message(i) }
  return ##class(%Exception.GeneralException).%New("winkle","",,msg)
}

ClassMethod generateSessionId() {
  //return $system.Encryption.Base64Encode($system.Encryption.GenCryptRand(20))
  return $system.Util.CreateGUID()
}

ClassMethod readHeaders(defaultAction) [ Private ] 
{
    //merge ^%cosmic("headers")=%request.CgiEnvs
    set ^||debug=($get(%request.CgiEnvs(..#DebugHeader),0)'=0)
    set ^||action=$get(%request.CgiEnvs(..#ActionHeader),defaultAction)
    set ^||fireForget=($get(%request.CgiEnvs(..#FireForgetHeader),0)'=0)
    set ^||sessionId=$get(%request.CgiEnvs(..#SessionIdHeader),..generateSessionId())
    do %response.SetHeader(..#SessionIdHeaderOut,^||sessionId)
    set ^||ns=$get(%request.CgiEnvs(..#NamespaceHeader),$namespace)
    if ( "postObject,create" '[ ^||action ) {
      throw ..ex("Invalid ",..#ActionHeader," header ='",^||action,"'")
    }
    set ^||headers=$listbuild(^||debug,^||action,^||fireForget,^||sessionId,^||ns)
    set ^%cosmic("^||headers")=^||headers
}

ClassMethod parseHeaders(headers) [ Private ]
{
  set ^||debug=$list(headers,1)
  set ^||action=$list(headers,2)
  set ^||fireForget=$list(headers,3)
  set ^||sessionId=$list(headers,4)
  set ^||ns=$list(headers,5)
}

ClassMethod post(className As %String) As %Status 
{
  try {
    do ..readHeaders("postObject")
    // Do the action, in-process if '^||fireForget
    if ( '^||fireForget ) {
      job $classmethod("jsoncls.HTTPService",^||action, className, ^||headers,%request)
      return $$$OK
    } else {
      return $classmethod("jsoncls.HTTPService",^||action, className, ^||headers,.%request)
    }
  } catch (error) {
    do ..logError(error)
    return error.AsStatus()
  }
}

ClassMethod postObject(className As %String, headers, request) As %Status
{
  try {
    do ..parseHeaders(headers)
    new $namespace set $namespace=^||ns
    set ^foo($zts)=request
    set object=$classmethod(className,"ImportFromStream",request.Content,.sc)
    throw:$$$ISERR(sc) ##class(%Exception.StatusException).CreateFromStatus(sc)
    //zw object
    set sc=object.%Save()
    throw:$$$ISERR(sc) ##class(%Exception.StatusException).CreateFromStatus(sc)
    if ( '^||fireForget ) {
      write object.ToJSON()
    }
    return $$$OK
  } catch (error) {
    do ..logError(error)
    return error.AsStatus()
  }
}

ClassMethod create(className As %String,headers,request) As %Status
{
  try {
    zw request
    do ..parseHeaders(headers)
    do ..debug("cosmic DEBUG ON",$c(13,10),"className=",className," Content-Size=",request.Content.Size)
    set jStream=%request.Content
    //zw jStream
    do ##class(jsoncls.Generator).Generate(className,.jStream)
    set package=$piece(className,".",1,$length(className,".")-1)
    do ..debug("Package=",package)
    set flags="ck-d"
    set:..dbg() flags="ckd"
    new $namespace set $namespace=^||ns
    do $system.OBJ.CompilePackage(package,"ck-d")
    set sc=##class(%Compiler.UDL.TextServices).GetTextAsStream(,className,.clsStream)
    if ($$$ISERR(sc) ) {
      return sc
    }
    do:'^||fireForget clsStream.OutputToDevice()
    return $$$OK
  } catch error {
     do ..logError(error)
     return error.AsStatus()
  }
}

ClassMethod clearErrors() As %Status
{
  try {
    do ..readHeaders("")
    kill ^%cosmic("errors",^||sessionId)
  } catch (error) {
    do ..logError(error)
    return error.AsStatus()
  }
  return $$$OK
}

ClassMethod getErrors() As %Status 
{
  try {
    do ..readHeaders("")
    set i=$order(^%cosmic("errors",^||sessionId),"")
    set errors=##class(%ListOfObjects).%New()
    while ( i'="" ) {
      set data=^%cosmic("errors",^||sessionId,i)
      set err=##class(%ZEN.proxyObject).%New()
      set err.timeStamp=$ZDT( $list(err,1),3,7 )
      set err.message=$list(err,2)
      do errors.Insert(err)
      set i=$order(^%cosmic("errors",^||sessionId),i)
    }
    do ##class(%ZEN.Auxiliary.jsonProvider).%ObjectToJSON(errors)
  } catch error {
    do ..logError(error)
    return error.AsStatus()
  }
  return $$$OK
}

ClassMethod logError(error) [ Private ]
{
  set i=$increment(^%cosmic("errors",^||sessionId))
  set ^%cosmic("errors",^||sessionId,i)=$listbuild($zts,error.DisplayString() )
  if ( '^||fireForget ) {
      set e=##class(%ZEN.proxyObject).%New()
      set e.timeStamp=$ZDT($ZTS)
      set e.message=error.DisplayString()
      do ##class(%ZEN.Auxiliary.jsonProvider).%ObjectToJSON(e)
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
	// create (if needed) %ALL namespace and add this package
	// to it - so it's available everywhere
	if ( '##class(Config.Namespaces).Exists("%ALL") ) {
		set properties("Globals")="CACHESYS"
		$$$THROWONERROR(sc,##class(Config.Namespaces).Create("%ALL",.properties))
		
	} 		
	set package=$piece(%class.Name,".",1,$length(%class.Name,".")-1)
	set sc=##class(Config.MapPackages).Get("%ALL",package,.maps)
	if ( '$data( maps("Database") ) ) {
		set maps("Database")="CACHESYS"
		$$$THROWONERROR(sc, ##class(Config.MapPackages).Create("%ALL",package,.maps))
	}	
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


