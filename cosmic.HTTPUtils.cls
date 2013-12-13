class cosmic.HTTPUtils extends %RegisteredObject
{

classmethod post(url,data) 
{
}

classmethod get(url)
{
	set req=..prepareRquest(url,.path)
	do req.Get( path ) 	
	if ( $isobject( req.HttpResponse.Data ) ) {
		set response=""
		while ( req.HttpResponse.Data.AtEnd ) {
			set response=response_req.HttpResponse.Data.Read() 
		}
		return response
	} else {
		return req.HttpResponse.Data
	}
	
}

classmethod post(url,message) 
{
	set req=..prepareRequest(url,.path)
	set req.ContentType="application/txt"
	do req.EntityBody.Write(message)
	do req.Post(path)

}
classmethod prepareRequest(url,output path) as %Net.HTTPRequest
{
	try {
		set req=##class(%Net.HTTPRequest).%New()
		set purl=##class(%New.URLParser).Parse(url)
		set req.Server=purl("host")
		if ( $zconvert(purl("scheme"),"l")="https" ) {
			set req.Https=1
			set req.Port=$get(purl("port"),443)
		} else {

			set req.Port=$get(purl("port"),80)
		}
		set:$get( purl("username") ) req.Username = purl("username")
		set:$get( purl("password") ) req.Password= purl("password")
		set path=purl("path")
		set:$l(purl("query")) path=path_"?"_purl("query")
		return req
	} catch error {
		do error.Log()
		throw error
	}
}

}
