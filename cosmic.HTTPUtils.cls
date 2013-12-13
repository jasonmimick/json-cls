class cosmic.HTTPUtils extends %RegisteredObject
{


classmethod get(url)
{
	set req=..prepareRequest(url,.path)
	set sc=req.Get( path ) 	
	if ( $isobject( req.HttpResponse.Data ) ) {
		set response=""
		while ( 'req.HttpResponse.Data.AtEnd ) {
			set response=response_req.HttpResponse.Data.Read() 
		}
		write response
		return response
	} else {
		zw req
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
classmethod prepareRequest(url,output path) as %Net.HttpRequest
{
	try {
		set req=##class(%Net.HttpRequest).%New()
		do ##class(%Net.URLParser).Parse(url,.purl)
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
		set:path="" path="/"
		set:$l(purl("query")) path=path_"?"_purl("query")
		return req
	} catch error {
		do error.Log()
		throw error
	}
}

}
