// =========================================================================
// Teaming functions                                                       \
// by Jack Abraham                                                      \__
// =========================================================================

key myTeam = NULL_KEY;
key oldTeam = NULL_KEY;
key newTeam = NULL_KEY;
key pendingTeam = NULL_KEY;
list teamURLs = [];

// -------------------------------------------------------------------------
// Security settings - remove if source is distributed
string PASSWORD = "ylADRIezoA1roeQiuDoUHl0douFro1Cr1e6iaSwi";
                                    // 40-character authentication
// -------------------------------------------------------------------------
                                    
integer dialogHandle;                   // Listen handle for dialog
integer teamPrim;                       // Prim where team is stored

integer RP_MASK             = 0x4000000;

team_activities( list parsed )
{
    string cmd = llList2String( parsed, 0 );
    
    if ( cmd == "menu" ) {
        // Teaming menu
        menu( "Manage Team", [ "Invite", "Leave", "List" ], [
            llDumpList2String( [ "act!", "team", "invt" ], 
                LINK_DELIM ),
            llDumpList2String( [ "act!", "team", "quit" ], 
                LINK_DELIM ),
            llDumpList2String( [ "act!", "team", "list" ], 
                LINK_DELIM )] );
    } else if ( cmd == "invt" ) {
        list team = get_team();
        if ( llGetListLength( team ) > 5 ) {
            llOwnerSay( "Team at maximum size." );
        } else {
            // Look for people to invite to your team
            llSensor( "", NULL_KEY, AGENT, 20.0, PI );
        }
    } else if ( cmd == "offer" ) {
        key who = (key)llList2String( parsed, 1 );
        offerRequest = get_data( who, ["team URL"], FALSE );
    } else if ( cmd == "join" ) {
        oldTeam = myTeam;
        newTeam = (key)llList2String( parsed, 1 );
        myTeam = newTeam;
        regRequest = put_data( llGetOwner(), [ "team URL", "team" ], 
            [ inURL, myTeam ], FALSE );
        llSay( 0, llGetObjectDesc() + " (" + llGetUsername( llGetOwner() ) +
            ") joined the team." );
    } else if ( cmd == "quit" ) {
        // Leave the team
        oldTeam = myTeam;
        myTeam = generateKey();
        dropRequest = put_data( llGetOwner(), [ "team URL", "team" ], 
            [ inURL, myTeam ], FALSE );
    } else if ( cmd == "drop" ) {
        teamRequest = get_team_auth( myTeam );
    } else if ( cmd == "updt" ) {
        // Update to the team membership
        myTeam = (key)llList2String( parsed, 1 );
        regRequest = put_data( llGetOwner(), [ "team URL", "team" ], 
            [ inURL, myTeam ], FALSE );
    } else if ( cmd == "list" ) {
        say_team();
    } else if ( cmd == "tsay" ) {
        // Send test message to the team
        sendRequest = team_send( myTeam, "send" + 
            llDumpList2String( llList2List( parsed, 1, -1 ), ACT_DELIM ) );
    }
}

// Return a list of team members
list get_team()
{
    list team = llCSV2List( 
        llList2String( 
            llGetLinkPrimitiveParams( teamPrim, [ PRIM_TEXT ] ),
            0 )
        );
    return team;
}

// Set the current team list
set_team( list team )
{
    list current = get_team();
    llSetLinkPrimitiveParamsFast( teamPrim,
        [ PRIM_TEXT, llList2CSV( team ), ZERO_VECTOR, 0.0 ] );
    if ( current != team ) {
        say_team();
    }
}

list onlineCheck;
check_online()
{
    onlineCheck = get_team();
    integer c = llGetListLength( onlineCheck );
    while ( c-- ) {
        onlineCheck = llListReplaceList( onlineCheck,
            [ llRequestAgentData( llList2Key( onlineCheck, c ), DATA_ONLINE ) ],
            c, c );
    }
}

// -------------------------------------------------------------------------
// Output functions

string CHAT_DELIM = "|";
string LINK_DELIM = "§";
string ACT_DELIM = ":";

menu( string title, list items, list commands )
{
    llMessageLinked( menuPrim, RP_MASK, 
        llDumpList2String( [ "menu", 
            title, 
            llList2CSV( items ), 
            llList2CSV( commands ) ],
            LINK_DELIM ),
        llGetOwner() );
}

say_team()
{
    list team = get_team();
    if ( team != [] ) {
        llOwnerSay( "Your team consists of secondlife:///app/agent/"
            + llDumpList2String( team, 
                "/about, secondlife:///app/agent/" )
            + "/about." );
    } else {
        llOwnerSay( "No one on your team." );
    }
}

// -------------------------------------------------------------------------

list get_link_numbers_for_names(list namesToLookFor)
{
    list linkNumbers = namesToLookFor;
    integer f = llGetNumberOfPrims();
    integer pos = -1;
    while (--f >= 0) {
        pos = llListFindList(namesToLookFor, [llGetLinkName(f)]);
        if (pos > -1) {
            linkNumbers = llListReplaceList(linkNumbers, [f], pos, pos);
        }
    }
    return linkNumbers;
}

integer menuPrim = LINK_SET;            // Where's the menu?

integer key2channel( key who ) {
    return -1 * (integer)( "0x" + llGetSubString( (string)who, -12, -5 ) );
}

// -------------------------------------------------------------------------
    
string inURL;
key regRequest;
key urlRequest;
key teamRequest;
key dropRequest;
key sendRequest;
key offerRequest;

integer COMMUNICATION_MASK  = 0x10000000;
string LINK_MSG_DELIM = "§";

key get_URL()
{
    llReleaseURL( inURL );
    inURL = "";
    return llRequestURL();
}

// ------------------------------------------------------------------------
// Database access
string DATA_URL = "http://mysticgems.geographic.net/act/auth.php";
string TEAM_URL = "http://mysticgems.geographic.net/act/team.php";
string SEND_URL = "http://mysticgems.geographic.net/act/teamsend.php";
string HTTP_DELIM = "|";

key namesID = NULL_KEY;                 // Get character names
key charKeyID = NULL_KEY;               // Get character key
key charID = NULL_KEY;                  // Character sheet request

key put_data(key id, list fields, list values, integer verbose)
{
    llSleep( 1.0 );
    string args;
    args += "?key=" + llEscapeURL(id) + "&separator=" 
        + llEscapeURL(HTTP_DELIM);
    args += "&fields=" + llEscapeURL(llDumpList2String(fields, HTTP_DELIM));
    args += "&values=" + llEscapeURL(llDumpList2String(values, HTTP_DELIM));
    args += "&secret=" + llEscapeURL( llSHA1String( PASSWORD + (string)id ) );
    return llHTTPRequest(DATA_URL + args,
        [HTTP_METHOD,"POST",HTTP_MIMETYPE,"application/x-www-form-urlencoded"],
        "");
}
        
// Send a team-related message to all team members
// Retransmitted by Mystic Gems server
key team_send( key id, string msg )
{
    string args;
    args += "?key=" + llEscapeURL(id);
    args += "&secret=" + llEscapeURL( llSHA1String( PASSWORD + (string)id ) );
    return llHTTPRequest(SEND_URL + args,
        [HTTP_METHOD,"POST",HTTP_MIMETYPE,"application/x-www-form-urlencoded"],
        msg );
}
        
key get_team_auth( key id )
{
    string args;
    args += "?key=" + llEscapeURL(id) + "&separator=" 
        + llEscapeURL(HTTP_DELIM);
    args += "&fields=team";
    args += "&secret=" + llEscapeURL( llSHA1String( PASSWORD + (string)id ) );
    return llHTTPRequest(TEAM_URL + args,
        [HTTP_METHOD,"GET",HTTP_MIMETYPE,"application/x-www-form-urlencoded"],
        "");
}

key get_data(key id, list fields, integer verbose)
{
    llSleep( 1.0 );
    string args;
    args += "?key=" + llEscapeURL(id) + "&separator=" 
        + llEscapeURL(HTTP_DELIM);
    args += "&fields=" + llEscapeURL( llDumpList2String( fields, HTTP_DELIM ) )
        + "&verbose=" + (string)verbose;
    args += "&secret=" + llEscapeURL( llSHA1String( PASSWORD + (string)id ) );
    return llHTTPRequest(DATA_URL + args,
        [HTTP_METHOD,"GET",HTTP_MIMETYPE,"application/x-www-form-urlencoded"],
        "");
}

integer date2int( string date )
{
    list parsed = llParseString2List( date, [ "-", "/", ":" ], [] );
    return (integer)(llList2String( parsed, 0 )  
        + llList2String( parsed, 1 ) 
        + llList2String( parsed, 2 ) );
}

key generateKey() {
    return llGenerateKey();
}

// ========================================================================

default
{
    state_entry()
    {
        list prims = get_link_numbers_for_names(
            [ "menu", "trgt:00000000-0000-0000-0000-000000000000" ] );
        menuPrim = llList2Integer( prims, 0 );
        teamPrim = llList2Integer( prims, 1 );
        set_team( [ llGetOwner() ] );
        myTeam = generateKey();
        urlRequest = get_URL();
    }
        
    attach( key id )
    {
        if ( id ) {
            // Get a new URL
            urlRequest = get_URL();
        }
    }
    
    link_message( integer sender, integer signal, string msg, key id )
    {
        if ( signal & RP_MASK ) {
            string cmd = llToLower( llGetSubString( msg, 0, 3 ) );
            
            if ( cmd == "act!" ) {
                list parsed = llParseStringKeepNulls( msg, 
                    [ LINK_DELIM, ACT_DELIM ], [] );
                cmd = llList2String( parsed, 1 );
                
                if ( cmd == "team" )
                {
                    team_activities( llList2List( parsed, 2, -1 ) );
                }
            } else if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "fmem" ) {
                llMessageLinked( sender, llGetFreeMemory(), "fmem", id );
            } else if ( cmd == "diag" ) {
                llWhisper( 0, "/me TEAM MANAGER\n" +
                    (string)llGetFreeMemory() + " bytes free" +
                     "\nTeam: " + llList2CSV( get_team() ) );
            } else if ( msg == "region" ) {
                // Changed region; renew the URL
                urlRequest = get_URL();
            }
        }
    }
    
    http_response(key request_id, integer status, list metadata, string body)
    {
        body = llStringTrim( body, STRING_TRIM );
        if ( request_id == regRequest || request_id == dropRequest ) {
            // Registering new team and/or team URL
            regRequest = NULL_KEY;
            if ( status != 200 ) {
                llOwnerSay( "Registration failed with status " 
                    + (string)status + ".\n" + body );
                llSleep( 60.0 );
                llResetScript();
            } else {
                if ( oldTeam != NULL_KEY ) {
                    // If we've switched teams, tell the old team about it
                    sendRequest = team_send( oldTeam, "updt" );
                    oldTeam = NULL_KEY;
                }
                if ( newTeam != NULL_KEY ) {
                    sendRequest = team_send( newTeam, "updt" );
                    newTeam = NULL_KEY;
                }
                // Update who's on my team
                teamRequest = get_team_auth( myTeam );
            }
        } else if ( request_id == offerRequest ) {
            if ( status == 200 && body != "NO_DATA" ) {
                llHTTPRequest( body,
                    [HTTP_METHOD,"POST",
                    HTTP_MIMETYPE,"text/plain"],
                    "join" + (string)myTeam);
                
            }
        } else if ( request_id == teamRequest ) {
            if ( status != 200 ) {
                llOwnerSay( "Failed to update team list from server.  Status "
                    + (string)status + ". " + body );
            } else {
                // Got updated team
                set_team( llParseString2List( body, [HTTP_DELIM], [] ) );
                check_online();
            }
        // } else if ( request_id == sendRequest ) {
            // Send to team successful
        //     llOwnerSay( "/me Team Chat response: " + body );
        }
    }

    http_request(key id, string method, string body)
    {
        if ( urlRequest == id) {                // New URL handling
            urlRequest = NULL_KEY;
            if (method == URL_REQUEST_GRANTED ) {
                inURL = body;
                key me = llGetOwner();
                // Register my team and my team URL
                regRequest = put_data( me, [ "team URL", "team" ], 
                    [ inURL, myTeam ], FALSE );
            }
        } else if ( method == "POST" ) {
            // Received message
            string cmd = llGetSubString( body, 0, 3 );
            body = llGetSubString( body, 4, -1 );
            if ( cmd == "updt" ) {
                teamRequest = get_team_auth( myTeam );
            } else if ( cmd == "join" ) {
                newTeam = (key)body;
                integer freq = llGetUnixTime();
                string requester = llGetHTTPHeader( id, 
                    "x-secondlife-owner-name" );
                dialogHandle = llListen( freq, "", llGetOwner(), "Join" );
                llDialog( llGetOwner(), requester + " invited you to join a team.",
                    [ "Join", "Decline" ], freq );
                llSetTimerEvent( 30.0 );
            } else if ( cmd == "send" ) {
                llOwnerSay( "/me Team: " + body );
            }
            llHTTPResponse( id, 200, "OK" );
        } else {
            // Hunh?
            llHTTPResponse( id, 404, "" );
        }
    }
    
    sensor( integer detected )
    {
        list names;
        list cmds;
        while ( --detected >= 0 ) {
            names += [ llDetectedName( detected ) ];
            cmds += [ llDumpList2String( [ "act!", "team", "offer", 
                llDetectedKey( detected ) ], LINK_DELIM ) ];
        }
        menu( "Recruiting", names + [ "CANCEL" ], cmds + [ "-" ] );
    }
    
    no_sensor()
    {
        menu( "No one to recruit", [ "OK" ], [] );
    }
    
    dataserver( key id, string data )
    {
        integer i = llListFindList( onlineCheck, [id] );
        if ( i > -1 ) {
            integer online = (integer)data;
            if ( !online ) {
                set_team( llDeleteSubList( get_team(), i, i ) );
                onlineCheck = llDeleteSubList( onlineCheck, i, i );
            }
        }
    }
    
    listen( integer channel, string who, key id, string heard )
    {
        if ( heard == "Join" )
        {
            // I joineed a new team
            oldTeam = myTeam;
            myTeam = newTeam;
            regRequest = put_data( llGetOwner(), [ "team URL", "team" ], 
                [ inURL, myTeam ], FALSE );
        }
        llListenRemove( dialogHandle );
    }
    
    timer()
    {
        if ( dialogHandle ) {
            // Remove dialog listeners
            llListenRemove( dialogHandle );
            dialogHandle = FALSE;
        }
    }
}

// Copyright ©2011 Jack Abraham and player, all rights reserved
// Contact Guardian Karu in Second Life for distribution rights