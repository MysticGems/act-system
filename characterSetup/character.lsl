// ===========================================================================
// Character Sheet read & upload                                             \
// By Jack Abraham                                                        \__ 
// ===========================================================================

key user = NULL_KEY;
key charKey = NULL_KEY;

integer USE_NULL = FALSE;

string charName = "Generic Character";  // Who am I?
string BLANK_CHARACTER = "( Unused )";  // Character name not set

float scale = 50.0;                     // Attribute scale
float TRAIT_COST = 0.025;               // Cost of a Trait
float SKILL_COST = 0.025;               // Cost of Skill +1.0

string VALUE_DELIM = "^";

integer dialogHandle;

store_all_values()
{
    list fields = [ "attributes" ];
    list values = [ attributes ];
    if ( traits ) {
        fields += "traits";
        values += llDumpList2String( traits, VALUE_DELIM );
    }
    if ( skills ) {
        fields += "skills";
        values += llDumpList2String( skills, VALUE_DELIM );
    }
    dataID = put_data( charKey, fields, values, TRUE );
}

string url = "http://brigadoon.geographic.net/act/auth.php";
string LICENSE_URL = "http://mysticgems.geographic.net/act/subscribe.php";
string RENAME_URL = "http://mysticgems.geographic.net/act/rename.php";
key putID;
key getID;
key delID;
key nameID;
key charID;
key dataID;
key renameID;
string PASSWORD = "REDACTED";
string separator = "|";     

key put_data(key id, list fields, list values, integer verbose)
{
    string args;
    args += "?key="+llEscapeURL(id)+"&separator="+llEscapeURL(separator);
//    args += "&char="+llEscapeURL(char);
    args += "&fields="+llEscapeURL(llDumpList2String(fields,separator));
    args += "&values="+llEscapeURL(llDumpList2String(values,separator));
    args += "&secret="+llEscapeURL(llSHA1String(PASSWORD + (string)id));
    return llHTTPRequest(url+args,[HTTP_METHOD,"POST",HTTP_MIMETYPE,"application/x-www-form-urlencoded"],"");
}

key get_license( key id )
{
    string args;
    //llOwnerSay( llGetScriptName() + " get license for " + (string)id +
    //    " " + llKey2Name( id ) );
    args += "?key=" + llEscapeURL(id);
    args += "&secret=" + llEscapeURL( llSHA1String( PASSWORD + (string)id ) );
    return llHTTPRequest(LICENSE_URL + args,
        [HTTP_METHOD,"GET",HTTP_MIMETYPE,"application/x-www-form-urlencoded"],
        "" );
}
        
key rename( key id, key uuid, string name )
{
    string body;
    //llOwnerSay( llGetScriptName() + " get license for " + (string)id +
    //    " " + llKey2Name( id ) );
    body += "key=" + llEscapeURL(id);
    body += "&uuid=" + llEscapeURL(uuid);
    body += "&name=" + llEscapeURL(name);
    body += "&secret=" + llEscapeURL( llSHA1String( PASSWORD + (string)id ) );
    return llHTTPRequest(RENAME_URL,
        [HTTP_METHOD,"POST",HTTP_MIMETYPE,"application/x-www-form-urlencoded"],
        body );
}
        
key get_data(key id, list fields, integer verbose)
{
    string args;
    args += "?key="+llEscapeURL(id)+"&action=get&separator="+llEscapeURL(separator);
    args += "&fields="+llEscapeURL(llDumpList2String(fields,separator))+"&verbose="+(string)verbose;
    args += "&secret="+llEscapeURL(llSHA1String(PASSWORD + (string)id));
    return llHTTPRequest(url+args,[HTTP_METHOD,"GET",HTTP_MIMETYPE,"application/x-www-form-urlencoded"],"");
}

integer date2int( string date )
{
    list parsed = llParseString2List( date, [ "-", "/", ":", " ", "T" ], [] );
    return (integer)(llList2String( parsed, 0 )  
        + llList2String( parsed, 1 ) 
        + llList2String( parsed, 2 ) );
}

del_data(key id, list fields, integer verbose)
{
    string args;
    args += "?key="+llEscapeURL(id)+"&action=del&separator="+llEscapeURL(separator);
    args += "&fields="+llEscapeURL(llDumpList2String(fields,separator))+"&verbose="+(string)verbose;
    args += "&secret="+llEscapeURL(llSHA1String(PASSWORD + (string)id));
    delID = llHTTPRequest(url+args,[HTTP_METHOD,"GET",HTTP_MIMETYPE,"application/x-www-form-urlencoded"],"");
}

integer key2channel( key who ) {
    integer chan = (integer)( "0x" + llGetSubString( (string)who, -12, -5 ) );
    if ( chan > 0 ) chan *= -1;
    if ( chan > -6 ) chan -= 500;
    return chan;
}

sheet_to_chat( vector rdi, vector smf, vector def, vector rec )
{
    string output = "/me - " + charName + "\n";
    output += "[Resilience: " + (string)llRound( rdi.x )
        + "] [Drive: " + (string)llRound( rdi.y )
        + "] [Insight: " + (string)llRound( rdi.z ) + "]";
    output += "\n[Morale: " + (string)llRound( smf.y )
        + "/" + (string)llRound( rdi.y + rdi.x )
        + "] [Focus: " + (string)llRound(smf.z ) + "/"
        + (string)llRound( rdi.y + rdi.z ) + "]";
    if ( traits != [] ) {
        output += "\n[Traits] " + llList2CSV( traits );
    }
    if ( skills != [] ) {
        list skillList = [];
        integer i = 0;
        integer c = llGetListLength( skills );
        do {
            float val = llList2Float( skills, i + 1 ) * 100.0;
            string skill = llList2String( skills, i ) + " ";
            if ( val >= 0.0 ) {
                skill += "+";
            }
            skill += (string)llRound( val );
            skillList += skill + "%";
            i += 2;
        } while ( i < c );
        output += "\n[Skills] " + llList2CSV( skillList );
    }
    llWhisper( 0, output );
}

// =========================================================================
// Reading character sheet
// =========================================================================
vector attributes;
list traits = [];
list skills = [];

string COMMENT = "//";
list CHARSHEET_DELIMITERS = [ ":", "=" ];

string nName = "*Character sheet";      // Character sheet notecard
integer nLine;
key nQueryID;
integer section;                        // 0 = attributes, 1 = traits, 
                                        // 2 = skills
list sheetHeaders = [ "[Attributes]", "[Traits]", "[Background]", "[Skills]" ];
integer ATTRIBUTES = 1;
integer TRAITS = 2;
integer BACKGROUND = 3;
integer SKILLS = 4;

queryNextLine() {
    ++nLine;
    nQueryID = llGetNotecardLine(nName, nLine);
}

// ===========================================================================
// Functions to store/retrieve attribute values

store( vector store, integer face )
{
    store /= 0xFFFFFF;
    if ( llGetColor( face ) != store ) {
        llSetColor( store, face );
    }
}

vector retrieve( integer face )
{
    return llGetColor( face ) * 0xFFFFFF;
}

// ===========================================================================

default // Setup
{
    state_entry()
    {
        nLine = 0;
        section = 0;
        attributes = ZERO_VECTOR;
        traits = [];
        skills = [];
        user = llGetOwner();
        if ( USE_NULL ) user = NULL_KEY;
        if ( llGetInventoryType( nName ) == INVENTORY_NOTECARD ) {
            llOwnerSay( "Reading " + nName + "." );
            nQueryID = llGetNotecardLine( nName, nLine );
        } else {
            // llOwnerSay( "/me couldn't find the " + nName + " notecard." );
            state error;
        }
    }
    
    on_rez( integer d )
    {
        llResetScript();
    }
    
    dataserver(key query_id, string data) 
    { 
        if (query_id == nQueryID) {
            if (data != EOF) {
                // Error check
                if ( llStringLength( data ) > 128 ) {
                    llOwnerSay( "/me encountered a problem reading your character sheet."
                            + "  Please check for problems with the  \"" + nName + 
                            "\" notecard." );
                    state error;
                }
                // Strip comments
                integer commentIndex = llSubStringIndex( data, "//" );
                if ( commentIndex + 1 ){
                     data = llDeleteSubString( data, commentIndex, -1);
                }
                data = llStringTrim( data, STRING_TRIM );
                // Is this a section header?
                integer headerIndex = 
                    llListFindList( sheetHeaders, [ data ] );
                if ( headerIndex > -1) {
                    section = headerIndex + 1;
                } else if ( ( llGetSubString( data, 0, 1 ) == COMMENT ) || 
                    ( data == "" ) ) 
                {
                    // queryNextLine();
                } else if ( section == BACKGROUND ) {
                    list keyval = 
                        llParseString2List( data, CHARSHEET_DELIMITERS, [] );
                    string name = llToLower( llList2String( keyval, 0 ) );
                    string val = llStringTrim( llList2String( keyval, 1 ),
                        STRING_TRIM );
                    
                    if ( name == "name" ) {
                        charName = val;
                    }
                } else if ( section == ATTRIBUTES ) {
                    list keyval = 
                        llParseString2List( data, CHARSHEET_DELIMITERS, [] );
                    string name = llStringTrim( 
                        llToLower( llList2String( keyval, 0 ) ),
                        STRING_TRIM );
                    float val = (float)llList2String( keyval, 1 );
                    if ( name == "resilience" ) {
                        attributes.x = val;
                    } else if ( name == "drive" ) {
                        attributes.y = val;
                    } else if ( name == "insight" ) {
                        attributes.z = val;
                    } else {
                        llOwnerSay( "Unknown attribute " + name + 
                            " in [Attributes] section." );
                        state error;
                    }
                } else if ( section == TRAITS ) {
                    traits += llStringTrim( llToLower( data ), STRING_TRIM );
                } else if ( section == SKILLS ) {
                    list keyval = 
                        llParseString2List( data, CHARSHEET_DELIMITERS, [] );
                    skills += llStringTrim(
                        llToLower( llList2String( keyval, 0 ) )
                        , STRING_TRIM );
                    
                    float value = (float)llStringTrim( 
                        llList2String( keyval, 1 ),
                        STRING_TRIM );
                    if ( llFabs( value ) > 1.0 ) {
                        value /= 100.0;
                    }
                    if ( llFabs( value ) > 1.0 ) {
                        llOwnerSay( "Skill " + llList2String( keyval, 0 ) + 
                            " outside of the range –1.0 to 1.0." );
                        state error;
                    }
                    skills += value;
                }
                queryNextLine();
            } else {                        // End of file; go active
                attributes = llVecNorm( attributes ) * scale;
                attributes *= 1.0 - 
                    ( TRAIT_COST * (float)llGetListLength( traits )) -
                    ( SKILL_COST * (float)( llListStatistics( LIST_STAT_SUM, skills ) ));
                attributes = <llRound( attributes.x ),
                    llRound( attributes.y ),
                    llRound( attributes.z )>;
                
                nameID = get_license( llGetOwner() );
            }
        }
    }

    http_response(key id, integer status, list metadata, string body)
    {
        body = llStringTrim( body, STRING_TRIM );
        if(!( id == charID || id == getID || id == dataID || id == nameID) ) return;
        
        if(status != 200) body = "ERROR: CANNOT CONNECT TO SERVER";
        if ( id == nameID ) {
            list parsed = llParseString2List( body, [separator], [] );
            integer i = llListFindList( parsed, [ charName ] );
            if ( i < 0 ) i = llListFindList( parsed, [ BLANK_CHARACTER ] );
            if ( i > -1 ) {
                parsed = llList2List( parsed, i, i + 3 );
                if ( date2int( llList2String( parsed, 3 ) ) < 
                    date2int( llGetTimestamp() ) )
                {
                    return llOwnerSay( "Expired license" );
                }
                scale = (float)llList2String( parsed, 2 );
                llOwnerSay( "Found license for " + llList2String( parsed, 0 ) );
                charKey = (key)llList2String( parsed, 1 );
                if ( llList2String( parsed, 0 ) != charName ) {
                    integer channel = llGetUnixTime();
                    dialogHandle = llListen( channel, "", llGetOwner(), 
                        "Rename" );
                    llDialog( llGetOwner(), 
                        "You do not have a character named \"" 
                        + charName 
                        + "\".  Do you want to use your blank character sheet?"  + " \nTHIS NAME WILL BE PERMANENT.", 
                        [ "Rename", "Cancel" ], channel );
                    llSetTimerEvent( 15.0 );
                } else {
                    store_all_values();
                }
            } else {
                return llOwnerSay( "No license for " + charName );
            }
            
        }
        if ( id == renameID ) {
            llOwnerSay( body );
        }
        if ( id == dataID ) {
            llOwnerSay( charName + " (" + (string)charKey + ") updated." );
        }
    }
    
    listen( integer channel, string who, key id, string msg )
    {
        if ( msg == "Rename" ) {
            llOwnerSay( "Using blank character sheet for "
                + charName + "." );
            renameID = rename( llGetOwner(), charKey, charName );
            store_all_values();
            llSetTimerEvent( 0.0 );
        }
    }

    changed( integer change )
    {
        if ( change & CHANGED_INVENTORY ) {
            llResetScript();
        }      
    }
    
    timer()
    {
        // Dialog timeout
        llOwnerSay( "No response in 15 seconds; ignoring updates." );
        llListenRemove( dialogHandle );
        llSetTimerEvent( 0.0 );
    }
}
    
state error
{
    state_entry()
    {
        llSleep( 1.0 );
    }        
    
    on_rez( integer p )
    {
        llResetScript();
    }
    
    changed( integer change )
    {
        if ( change & CHANGED_INVENTORY ) {
            llResetScript();
        }
    }
}