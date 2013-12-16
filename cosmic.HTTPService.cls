Class cosmic.HTTPService Extends %CSP.REST
{
XData UrlMap 
{
  <Routes>
    <Route Url="/getErrors" Method="GET" Call="getErrors" />
    <Route Url="/clearErrors" Method="GET" Call="clearErrors" />
    <Route Url="/mq/:channel" Method="GET" Call="mqListen" />
    <Route Url="/mq/:channel" Method="POST" Call="mqSendMessage" />
    <Route Url="/:className" Method="POST" Call="post" />
  </Routes>
}

Parameter ActionHeader = "HTTP_X_COSMIC_ACTION";

Parameter DebugHeader = "HTTP_X_COSMIC_DEBUG";

Parameter FireForgetHeader= "HTTP_X_COSMIC_DONOT_FIREANDFORGET";

Parameter SessionIdHeader = "HTTP_X_COSMIC_SESSION";
Parameter SessionIdHeaderOut = "X_COSMIC_SESSION";

Parameter NamespaceHeader = "HTTP_X_COSMIC_NAMESPACE";

Classmethod stringfromarray(byref array) as %String
{
	set string=""
	for i=1:1:array { set string=string_array(i) }
	return string
}

ClassMethod exp(message... as %String) [ Private ]
{
	do ..debug(message)
    return ##class(%Exception.General).%New("cosmic",,,..stringfromarray(.message))
}

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
      job $classmethod("cosmic.HTTPService",^||action, className, ^||headers,%request)
      return $$$OK
    } else {
      return $classmethod("cosmic.HTTPService",^||action, className, ^||headers,.%request)
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
    do ##class(cosmic.Generator).Generate(className,.jStream)
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

Classmethod mqListen(channel as %String) As %Status
{
	try {
    	do ..readHeaders("")
		// parse out the endpoint
		// only works for GET so nn
		// must be in request query
		set pek=$order(%request.Data(""))
		set pe=%request.Data(pek)
		set ^%cosmic.mq(channel)=$get(^%cosmic.mq)_$listbuild(pe)
	} catch error {
		do ..logError(error)
		return error.AsStatus()
	}
	return $$$OK
}

Classmethod mqSendMessage(queue as %String) As %Status
{
	try {
    	do ..readHeaders("")
		// get the message and then based on fire-and-forget
		// send it
		if ( %request.Content.Size > 0 ) {
			set message = ""
			while ( '%request.Content.AtEnd ) {
				set message = message _ %request.Content.Read()
			}
		} else {
			// look in Data
			set key=$order( %request.Data("") )
			set message = %request.Data(key)
		}
		if (^||fireForget) {
			job $classmethod("cosmic.HTTPService","sendMessage",queue,message)
		} else {
			do ..sendMessage(queue,message)
		}
	} catch error {
		do ..logError(error)
		return error.AsStatus()
	}
	return $$$OK
}

Classmethod sendMessage(channel,msg) [ Private ]
{
	set created='$system.Event.Create(channel) 
	do ..debug("created channel='",channel,"'")
	set ok=$system.Event.Signal(channel, msg)
	if ('ok) {
		do ..exp("error signalling channel=",channel," msg=",msg) 
	}
}

/// Jobbed off deamon will listen on 
/// a particular channel. When a message
/// is received it will broadcast it to each
/// endpoint in the $list stored in
/// ^%cosmic.mq(channel)
/// if ^%comsmic.mq(channel,"stop")=1
/// then the job will exit
Classmethod listenDeamon(channel) [ Private ]
{
	set timeout=$get(^%cosmic.mq.sys("timeout"),30)
	set stop=$get(^%cosmic.mq(channel,"stop"),0)
	while ( 'stop ) {
			set signal=$system.Event.WaitMsg(channel,timeout)
			set listeners=^%comsic.mq(channel)
			for i=1:1:$listlength(listeners) {
				do broadcast( $list(listeners,i), $list(signal,2) )
			}
			// check if we should shutdown
			set stop=$get(^%cosmic.mq(channel,"stop"))
	}
}

ClassMethod mqListen()	As %Status
{
	try {
	
		
		return $$$OK
	} catch error {
		do ..log(error)
		return error.AsStatus()
	}
	
	
}
Classmethod broadcast(endpoint,message)
{
	do ##class(cosmic.HTTPUtils).post(endpoint,message)
}

Parameter CSPAPP = "/cosmic";

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


