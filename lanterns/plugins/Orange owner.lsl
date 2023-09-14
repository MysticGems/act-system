// ===================================================================
// Agent Orange Agent Controller                                     \
// by Jack Abraham                                                \__
// ===================================================================

// Modified to allow any power source

// -------------------------------------------------------------------------
// Security settings - remove if source is distributed
string PASSWORD = "REDACTED";
                                    // 40-character authentication
// -------------------------------------------------------------------------

list agents = [];
list agentNames = [];

key getAgentsHTTP;                  // request for all agents
key getAgentURLHTTP;                // request for an agent's URL
key getAgentNameDS;
key getTeamHTTP;                    // Getting my team
key agentMenuHTTP;
key testAgentURLHTTP;               // agent URL being tested

key activeAgent;                    // Agent we're commanding

key postAgentCommandHTTP;           // Post command

integer BROADCAST_MASK      = 0xFFF00000;
integer COMMUNICATION_MASK  = 0x10000000;
integer UI_MASK             = 0x80000000;
integer RP_MASK             = 0x4000000;
integer AVARICE_MASK        = 0x20010000;
string LINK_MSG_DELIM = "§";
string CHAT_MSG_DELIM = "|";
integer RETRIES = 5;

integer POWER_MASK = 0x3F;
integer POWER_FACE = 1;                 // Face where power levels are stored
integer powerPrim;                      // Prim where power type is stored

// -------------------------------------------------------------------

handle_command( list commands )
{
    string cmd = llList2String( commands, 0 );
    if ( cmd == "activate" ) {
        set_active_agent( (key)llList2String( commands, 1 ) );
        return;
    } else if ( cmd == "select" ) {
        activeAgent = NULL_KEY;
        select_agent_menu();
        return;
    } else if ( cmd == "summon" ) {
        list details =  llGetObjectDetails( llGetOwner(), [ OBJECT_POS,
            OBJECT_ROT ] );
        vector here = llList2Vector( details, 0 ) + ( <2, 0, 0> *
            llList2Rot( details, 1 ) ) + llGetRegionCorner();
        postAgentCommandHTTP = send_command( [ "trvl", "tpto", here ] );
    } else if ( cmd == "trgt" ) {
        postAgentCommandHTTP = send_command( [ "trgt", get_target() ] );
    } else if ( cmd == "chase" ) {
        send_command( [ "trgt", get_target() ] );
        postAgentCommandHTTP = send_command( [ "trvl", "follow" ] );
    } else if ( cmd == "leash" ) {
        send_command( [ "trgt", llGetOwner() ] );
        postAgentCommandHTTP = send_command( [ "trvl", "follow" ] );
    } else if ( cmd == "ntgt" ) {
        postAgentCommandHTTP = send_command( [ "trgt", NULL_KEY ] );
    } else if ( cmd == "atk" ) {
        send_command( [ "trgt", get_target() ] );
        postAgentCommandHTTP = send_command( [ "chmd", "combat" ] );
        llSleep( 1.0 );
        send_command( [ "cmbt", "auto", "on" ] );
    } else if ( cmd == "peace" ) {
        send_command( [ "cmbt", "auto", "off" ] );
        postAgentCommandHTTP = send_command( [ "trgt", llGetOwner() ] );
    }
    menu();
}

list menuItems;
list menuCommands;

menu()
{
    menuItems = [];
    menuCommands = [];
    string prefix = llGetScriptName() + LINK_MSG_DELIM;
    if ( activeAgent ) {
        menuItems = [ "SELECT", "Attack", "Peace",
            "Summon", "Target", "Chase Target", "Follow Me",
            "No Target/Stop Follow", "Attack", "Peace" ];
        menuCommands = [
            prefix + "atk", prefix + "peace",
            prefix + "select", prefix + "summon", prefix + "trgt",
            prefix + "chase", prefix + "leash", prefix + "ntgt"
            ];
        send_menu( llList2String( agentNames,
            llListFindList( agents, [activeAgent] )));
    } else {
        select_agent_menu();
    }
}

select_agent_menu()
{
    menuItems = [];
    menuCommands = [];
    integer c = llGetListLength( agents );
    if ( c ) {
        string this = llGetScriptName();
        while ( c-- > 0 ) {
            menuItems += llList2String( agentNames, c );
            menuCommands += this + LINK_MSG_DELIM + "activate" +
                LINK_MSG_DELIM + llList2String( agents, c );
        }
        send_menu( "Select Agent" );
    } else {
        llMessageLinked( LINK_ROOT, COMMUNICATION_MASK,
            llDumpList2String( [ "IM", "No agents." ], LINK_MSG_DELIM ),
            llGetOwner() );
    }
}

integer menuPrim;
send_menu( string name )
{
    llMessageLinked( menuPrim, AVARICE_MASK,
        llDumpList2String( [ "menu",
            name,
            llList2CSV( menuItems ),
            llList2CSV( menuCommands ) ],
            LINK_MSG_DELIM ),
        llGetOwner() );
}

// -------------------------------------------------------------------
// Database access
string DATA_URL = "http://mg.geographic.net/auth.php";
string HTTP_DELIM = "|";

key get_data(key id, list fields, integer verbose, integer reverse)
{
    llSleep( 1.0 );
    string args;
    args += "?key=" + llEscapeURL(id) + "&separator="
        + llEscapeURL(HTTP_DELIM);
    args += "&fields=" + llEscapeURL( llDumpList2String( fields, HTTP_DELIM ) )
        + "&verbose=" + (string)verbose + "&reverse=" + (string)reverse;
    args += "&secret=" + llEscapeURL( llSHA1String( PASSWORD + (string)id ) );
    return llHTTPRequest(DATA_URL + args,
        [HTTP_METHOD,"GET",HTTP_MIMETYPE,"application/x-www-form-urlencoded"],
        "");
}

string TEAM_URL = "http://mysticgems.geographic.net/act/auth.php";
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

key put_data(key id, string where, string data, integer verbose)
{
    llSleep( 1.0 );
    string args;
    args += "?key=" + llEscapeURL(id) + "&separator="
        + llEscapeURL(HTTP_DELIM);
    args += "&fields=" + llEscapeURL(where);
    args += "&values=" + llEscapeURL(data);
    args += "&secret=" + llEscapeURL( llSHA1String( PASSWORD + (string)id ) );
    return llHTTPRequest(DATA_URL + args,
        [HTTP_METHOD,"POST",HTTP_MIMETYPE,"application/x-www-form-urlencoded"],
        "");
}

// -------------------------------------------------------------------

string SEND_URL = "http://mysticgems.geographic.net/agentsend.php";
key send_command( list command )
{
    if ( activeAgent ) {
        integer c = llGetListLength( command );
        //while ( c > 0 ) {
        //    c--;
        //    command = llListReplaceList( command, [ llEscapeURL(
        //        llList2String( command, c ) ) ], c, c );
        //}
        c = RETRIES;
        key result = NULL_KEY;
        while ( c > 0 && result == NULL_KEY ) {
            result = llHTTPRequest( SEND_URL + "?key=" + (string)activeAgent,
                [HTTP_METHOD,"POST",
                    HTTP_MIMETYPE,"application/x-www-form-urlencoded",
                    HTTP_VERBOSE_THROTTLE,FALSE],
                llDumpList2String( command, CHAT_MSG_DELIM ) );
        }
        if ( result == NULL_KEY ) {
            agent_comm_failure();
        }
        return result;
    }
    return NULL_KEY;
}

set_active_agent( key id )
{
    activeAgent = id;
    testAgentURLHTTP = send_command( [ "IM",
        llGetDisplayName( llGetOwner() ) +
        " has power over you." ] );
}

string agent_name( key id )
{
    integer i = llListFindList( agents, [id] );
    string name;
    if ( i > -1 ) {
        name = llList2String( agentNames, i );
//        if ( (key)name == NULL_KEY ) {
            return name;
  //      }
    }
    return "(Unknown)";
}

update_agents()
{
    activeAgent = NULL_KEY;
    agents = [ (key)"1bb63775-461a-0ee7-9f67-7d737bf53b92" ];
    agentNames = [ "Sample" ];
    // getAgentsHTTP = get_data( llGetOwner(), ["master"], FALSE, TRUE );
}

agent_comm_failure()
{
    string name = agent_name( activeAgent );
    llMessageLinked( LINK_ROOT, COMMUNICATION_MASK,
        llDumpList2String( [ "IM", "Cannot reach Agent "
            + name + "; ring not responding." ], LINK_MSG_DELIM ),
        llGetOwner() );
    send_status( name + " disconnected" );
    integer i = llListFindList( agents, [ activeAgent ] );
    agents = llDeleteSubList( agents, i, i );
    agentNames = llDeleteSubList( agentNames, i, i );
    activeAgent = NULL_KEY;
    update_agents();
}

send_status( string msg )
{
    llMessageLinked( LINK_ROOT, COMMUNICATION_MASK,
        llDumpList2String( [ "status", msg, 10.0 ], LINK_MSG_DELIM ),
        llGetOwner() );
}

// -------------------------------------------------------------------------

key get_target()
{
    return (key)llLinksetDataRead( "target" );
}

// Get integer power type
integer get_source()
{
    vector powerAttrib = llList2Vector(
        llGetLinkPrimitiveParams( powerPrim,
            [ PRIM_COLOR, POWER_FACE ] ), 0 ) * 0xFF;
    return (integer)powerAttrib.x & POWER_MASK;
}

integer find_prim_named( string name )
{
    integer i = llGetNumberOfPrims();
    name = llToLower( name );
    while( --i > 0 ) {
        if ( llToLower( llGetLinkName( i ) ) == name ) {
            return i;
        }
    }
    return LINK_SET;
}

// ===================================================================

default
{
    state_entry()
    {
        menuPrim = find_prim_named("menu");
        powerPrim = find_prim_named("construct");
        update_agents();
    }

    attach( key id )
    {
        if ( id ) {
            activeAgent = NULL_KEY;
            update_agents();
        }
    }

    http_response( key id, integer status, list meta, string body )
    {
        body = llStringTrim( body, STRING_TRIM );
        if ( id == getAgentsHTTP ) {
            // Got the list of agents & URLs back
            agents = llParseString2List( body, [HTTP_DELIM], [] );

            // Remove me
            integer i = llListFindList( agents, [ (string)llGetOwner() ] );
            if ( i > -1 ) {
                agents = llDeleteSubList( agents, i, i );
            }

            agentNames = [];
            integer k = llGetListLength( agents );
            for ( i=0; i < k; i++ ) {
                agents = llListReplaceList( agents,
                    [ (key)llList2String( agents, i ) ],
                    i, i );
                agentNames += llRequestDisplayName( llList2Key( agents, i ) );
            }
        }
        if ( id == testAgentURLHTTP ) {
            if ( status != 200 ) {
                agent_comm_failure();
            } else {
                send_status( "Agent " + agent_name(activeAgent) +
                    " selected." );
                menu();
                getTeamHTTP = get_team_auth( llGetOwner() );
            }
        }
        if ( id == getTeamHTTP ) {
            if ( status == 200 ) {
                if ( activeAgent ) {
                    send_command( [ "act!", "team", "join", body ] );
                }
            }
        }
        if ( id == postAgentCommandHTTP ) {
            if ( status != 200 ) {
                if ( status == 403 ) {
                    send_status( "Agent refused command." );
                }
                agent_comm_failure();
            }
        }
    }

    dataserver( key id, string data )
    {
        // Populate agentNames with dataserver names
        integer i = llListFindList( agentNames, [id] );
        if ( i > -1 ) {
            agentNames = llListReplaceList( agentNames, [ data ], i, i );
        }
    }

    link_message( integer sender, integer num, string msg, key id )
    {
        list parsed = llParseString2List( msg, [ LINK_MSG_DELIM ], [] );
        string cmd = llList2String( parsed, 0 );
        if ( cmd == llGetScriptName() )
        {
            if ( get_source() != 2 ) {
                // Not powered by avarice
                llOwnerSay( "Agent Orange not powered by avarice?" );
            //    return;
            }
            string cmd = llList2String( parsed, 1 );
            if ( num == AVARICE_MASK ) {
                handle_command( llList2List( parsed, 1, -1 ) );
            } else {
                menu();
            }
        } else if ( cmd == "aura" ) {
            if ( get_source() != 2 ) {
                // Not powered by avarice
                return;
            }
            menu();
        } else if ( cmd == "aupd" ) {
            update_agents();
        }
    }
}