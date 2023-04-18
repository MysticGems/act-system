// ===========================================================================
// Character Sheet                                                           \
// By Jack Abraham                                                        \__ 
// ===========================================================================

// use LSD and either web or experience storage

string ACT_PREFIX = "act#";

integer readTrait( string trait ) {
    string val = llLinksetDataRead( ACT_PREFIX + trait );
    if ( val ) {
        return (integer)val;
    }
    return FALSE;
}
updateTrait( string trait, string value ) {
    string val = llLinksetDataWrite( ACT_PREFIX + trait, value );
    if ( val && val != LINKSETDATA_NOUPDATE ) {
        llOwnerSay( "Error " + (string)val + " updating " + trait )
    }
}

// Experience keys access with failover to SLDB
string SECURE_HEADER_VALUE = "SOME_STRING";
string SLDB_URL = "Lambda URL with trailing slash";
key requestId = NULL_KEY;
integer requestType = 0;
integer REQUEST_TYPE_CHARACTER_SHEET = 1;

readKeyValue( string data_key, integer infoType ) {
    if ( llAgentInExperience( llGetOwner() )) {
        requestId = llReadKeyValue( data_key );
    } else {
        string hash = llSHA1String(
            (string)llGetKey() + data_key + SECURE_HEADER_VALUE
            );
        requestId = llHTTPRequest(
            SLDB_URL + data_key,
            [ HTTP_CUSTOM_HEADER, "secure", hash ],
            ""
        );
    }
}

updateKeyValue( string data_key, string value, integer infoType ) {
    string hash = llSHA1String(
        (string)llGetObjectKey() + data_key + SECURE_HEADER_VALUE
        );
    requestId = llHTTPRequest(
        SLDB_URL + data_key,
        [ HTTP_METHOD, "PUT",
          HTTP_CUSTOM_HEADER, "Authentication", hash ],
        value
    );
}

parse_response(string body) {
    if (llGetSubString(body, 0, 0) != "1")
    {
        integer error =  (integer)llGetSubString(body, 2, -1);
        llSay(0, "Key-value failed to read: " + llGetExperienceErrorMessage(error));

    }
    body = llGetSubString(body, 2, -1);
    if ( requestType == REQUEST_TYPE_CHARACTER_SHEET) {
        writeJsonCharacter( body );
    }
}

writeJsonCharacter( string json ) {
    list traits = llJson2List( json );
    integer loop = 0;
    integer end = llGetListLength( traits );
    while( loop < end ) {
        updateTrait( llList2String( traits, loop ), llList2String( traits, loop+1 ) );
        loop += 2;
    }
}

// ===========================================================================
default {
    // Response from Experience
    dataserver( key id, string body )
    {
        if (id == requestId)
        {
            parse_response( body );
            requestId = NULL_KEY;
        }
    }
    // Response from off-world data server
    http_response(key id, integer status, list metaData, string body)
    {
        if (id == requestId)
        {
            if ( status == 200 ) {
                parse_response(body);
            } else {
                llSay(0, "HTTP Error: " + (string)status + "\n" + body);
            }
            requestId = NULL_KEY;
        }
    }
}