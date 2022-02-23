// =========================================================================
// Plugin manager                                                          \
// by Jack Abraham                                                      \__
// =========================================================================

integer BROADCAST_MASK     = 0xFFF00000;
integer PLUGIN_MASK        = 0x20000000;
integer COMMUNICATION_MASK = 0x10000000;
string LINK_DELIM = "§";
string CHAT_DELIM = "|";
integer THIS_SCRIPT_MEMORY = 16384;

integer freeMemory;

integer installHandle;
integer installChannel;

integer pin = 0;                        // Remote script access PIN

plugin_menu( string title, string commandPrefix, list menuItems, 
    list menuCommands )
{
    integer c = llGetInventoryNumber( INVENTORY_SCRIPT );
    integer i;
    string this = llGetScriptName();
    string name;
    if ( commandPrefix ) {
        commandPrefix += LINK_DELIM;
    }
    do {
        name = llGetInventoryName( INVENTORY_SCRIPT, i );
        if( name != this && llGetSubString( name, 0, 0 ) != "~" )
        {
            menuItems += [ name ];
            menuCommands += [ commandPrefix + name ];
        }
    } while ( ++i < c );
    llMessageLinked( menuPrim, PLUGIN_MASK, 
        llDumpList2String( [ "menu", 
            "Plugin Menu", 
            llList2CSV( menuItems ), 
            llList2CSV( menuCommands ) ],
            LINK_DELIM ),
        llGetOwner() );
}

integer key2channel( key id )
{
    return -1 * (integer)( "0x" + llGetSubString( (string)id, -10, -3 ) );
}

string PASSWORD = "yudruruse8uXucaswu5raBrun6h59e2ucufrajuf";

integer authenticate( string msg, key id )
{
    string signature = llGetSubString( msg, -40, -1 );
    string timestamp = llGetSubString( msg, -44, -41 );
    msg = llGetSubString( msg, 0, -45 );
    string hash = llSHA1String( (string)llGetOwner() + PASSWORD + msg +
        timestamp );
    return hash == signature;    
}

string sign( list message, key id )
{
    string msg = llDumpList2String( [ llGetOwner() ] + message, 
        CHAT_DELIM );
    string timestamp = llGetSubString( (string)llGetUnixTime(), -4, -1 );
    return msg + timestamp
        + llSHA1String( (string)llGetKey() + PASSWORD + msg + timestamp );
}

string encrypt ( string data ) {
    return llXorBase64StringsCorrect( llStringToBase64( data ),
        llStringToBase64( PASSWORD ) );
}

integer menuPrim;

integer get_prim_named( string name )
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

// =========================================================================

default
{
    state_entry()
    {
        llSetRemoteScriptAccessPin( 0 );
        menuPrim = get_prim_named( "menu" );
        llMessageLinked( LINK_ROOT, COMMUNICATION_MASK,
            llDumpList2String( [ "unstatus", "Installing plugin" ],
            LINK_DELIM ), NULL_KEY );
    }
    
    on_rez( integer p )
    {
        llSetRemoteScriptAccessPin( 0 );
    }
    
    attach( key id )
    {
        if ( id ) {
            llRequestPermissions( id, PERMISSION_TAKE_CONTROLS );
        }
    }
    
    run_time_permissions( integer perm )
    {
        if ( perm & PERMISSION_TAKE_CONTROLS )
        {
            llTakeControls( 1024, FALSE, TRUE );
        }
    }
    
    link_message( integer source, integer flag, string msg, key id )
    {
        if( flag & PLUGIN_MASK ) {
            list parsed = llParseString2List( msg, [ LINK_DELIM ], [] );
            string cmd = llList2String( parsed, 0 );
            
            if ( cmd == "plug" ) {
                cmd = llList2String( parsed, 1 );
                if ( llGetSubString( cmd, 0, 2 ) == "add" ) {
                    if ( llGetOwnerKey( id ) == llGetOwner() ) {
                        installChannel = 
                            (integer)llList2String( parsed, 2 );
                        installHandle = llListen( installChannel, 
                            "", id, "" );
                        llWhisper( installChannel, "authenticate" );
                    }
                } else if ( cmd == "menu" ) {
                    plugin_menu( "Plugin menu", "", [ "STATUS", "REMOVE" ],
                        [ "plug" + LINK_DELIM + "status"
                        , "plug" + LINK_DELIM + "rmenu" ] );
                } else if ( cmd == "rmenu" ) {
                    plugin_menu( "Remove Plugin", llDumpList2String(
                        [ "plug", "remove" ], LINK_DELIM ), [], [] );
                } else if ( cmd == "remove" ) {
                    llMessageLinked( LINK_ROOT, COMMUNICATION_MASK,
                        llDumpList2String( [ "status", "Removing plugin" ],
                        LINK_DELIM ), id );
                    llMessageLinked( LINK_ROOT, BROADCAST_MASK,
                        llDumpList2String( [ "busy", 10.0 ],
                        LINK_DELIM ), id );
                    string plugin = llList2String( parsed, 2 );
                    llMessageLinked( LINK_THIS, PLUGIN_MASK,
                        llDumpList2String( [ plugin, "remove" ], LINK_DELIM ),
                        id );
                    llSleep( 10.0 );
                    if (llGetInventoryType( plugin ) == INVENTORY_SCRIPT &&
                        plugin != llGetScriptName() ) 
                    {
                        llRemoveInventory( plugin );
                    }
                    llMessageLinked( LINK_ROOT, COMMUNICATION_MASK,
                        llDumpList2String( [ "unstatus", "Removing plugin" ],
                        LINK_DELIM ), id );
                } else if ( cmd == "status" ) {
                    integer hudMemory = llList2Integer( 
                        llGetObjectDetails( llGetLinkKey( LINK_ROOT ), 
                            [ OBJECT_SCRIPT_MEMORY ] )
                        , 0 );
                    llOwnerSay( "HUD memory: " + (string)hudMemory );
                }
            } else if ( cmd == "diag" ) {
                state diag;
            } else if ( cmd == "rset" ) {
                llResetScript();
            }
        }
    }
        
    listen( integer channel, string who, key id, string msg )
    {
        if ( authenticate( msg, id ) ) {
            llMessageLinked( LINK_ROOT, COMMUNICATION_MASK,
                llDumpList2String( [ "status", "Installing plugin" ],
                LINK_DELIM ), id );
            llMessageLinked( LINK_ROOT, COMMUNICATION_MASK,
                llDumpList2String( [ "IM", "Installing plugin from " +
                    llKey2Name( id ) + "." ],
                LINK_DELIM ), id );
            llMessageLinked( LINK_ROOT, BROADCAST_MASK,
                llDumpList2String( [ "busy", 10.0 ],
                LINK_DELIM ), id );
            pin = llGetUnixTime() ^ 
                (integer)llFrand( 16000000.0 );
            llSetRemoteScriptAccessPin( pin );
            llWhisper( installChannel,
                llDumpList2String(
                    [ "plug", "pin", 
                        encrypt( (string)pin ) ],
                    CHAT_DELIM )
                );
            llSetTimerEvent( 10. );
        }
        llListenRemove( installHandle );
        installHandle = FALSE;
    }
        
    timer()
    {
        llMessageLinked( LINK_ROOT, COMMUNICATION_MASK,
            llDumpList2String( [ "unstatus", "Installing plugin" ],
            LINK_DELIM ), NULL_KEY );

        llResetScript();
    }
}

state diag
{
    state_entry()
    {
        integer plugMemory= llList2Integer( 
            llGetObjectDetails( llGetLinkKey( LINK_ROOT), 
                [ OBJECT_SCRIPT_MEMORY ] )
            , 0 );
        llWhisper( 0, "PLUGIN MANAGER\n" + (string)llGetUsedMemory() 
            + " bytes used\n"
            + (string)( llGetInventoryNumber( INVENTORY_SCRIPT ) - 1 ) 
            + " plugins\n"
            + (string)( plugMemory / 1024 )+ "kb memory in HUD" );
        freeMemory = llGetFreeMemory();
        llSetTimerEvent( 1.0 );
        llMessageLinked( LINK_SET, BROADCAST_MASK, "fmem", llGetKey() );
    }
    
    link_message( integer source, integer flag, string msg, key id )
    {
        if ( msg == "fmem" ) {
            freeMemory += flag & ~BROADCAST_MASK;
        }
    }
    
    timer()
    {
        integer memory= llList2Integer( 
            llGetObjectDetails( llGetLinkKey( LINK_ROOT), 
                [ OBJECT_SCRIPT_MEMORY ] )
            , 0 );

        llWhisper( 0, "MEMORY USAGE\nUsing " + (string)(memory - freeMemory)
            + " of " + (string)memory + " allocated." );
        state default;
    }
    
    on_rez( integer d )
    {
        state default;
    }
}

