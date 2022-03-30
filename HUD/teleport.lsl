// =========================================================================
// Teleport controller                                                     \
// By Jack Abraham                                                      \__
// =========================================================================

integer TP_FOCUS = 40;                  // Teleport focus cost

list history;                           // Locations as parcel name, region 
list saved;                             // name, and global coordinates

integer STRIDE = 2;
integer MAX_LOCATIONS = 20;
integer NAME_LENGTH = 15;

float UPDATE_INTERVAL = 60.0;           // How often to check where we are
vector here;                            // Where we are (global coordinates)
vector last;                            // Location for auto-return
string trailURL;                        // URL to notify after TP

integer BROADCAST_MASK      = 0xFFF00000;
integer NAV_MASK            = 0x40000000;
integer RLV_MASK            = 0x20000000;
integer COMMUNICATION_MASK  = 0x10000000;
integer OBJ_MASK            = 0x2000000;
integer RP_MASK             = 0x4000000;
integer UI_MASK             = 0x80000000;
integer FLAG_FACE = 1;                  // Face with flag values set

string LINK_DELIM = "§";
string CHAT_DELIM = "|";
integer rlvEnabled = FALSE;

integer inTransit = FALSE;
string teleportSound;

string tpURL;                           // URL to inform of next teleport

nav_commands( list commands )
{
    string cmd = llList2String( commands, 0 );
    if ( cmd == "tp" ) {
        tp_menu();
    } else if ( cmd == "tpto" ) {
        tpto( (vector)llList2String( commands, 1 ) );
    } else if ( cmd == "turl" ) {
        tpURL = llList2String( commands, 1 );
        llOwnerSay( llGetScriptName() + " registered tp URL " + tpURL );
    } else if ( cmd == "save" ) {
        save();
    } else if ( cmd == "clear" ) {
        saved = [];
        history = [];
        load_landmarks();
    } else if ( cmd == "rtrn" ) {
        tpto( last );
    }
}

integer menuPrim = LINK_SET;

tp_menu()
{
    integer c = llGetListLength( saved ) - STRIDE;
    list menuItems = [ "SAVE", "CLEAR", "RETURN" ];
    list menuCommands = [ llDumpList2String( [ "trvl", "save" ],
        LINK_DELIM ),
        llDumpList2String( [ "trvl", "clear" ], LINK_DELIM ),
        llDumpList2String( [ "trvl", "rtrn" ], LINK_DELIM ) ];
    string item;
    
    if ( c >= 0 ) {
        do {
            menuItems += llList2String( saved, c );
            menuCommands += [ llDumpList2String( 
                [ "trvl", "tpto"
                , llList2Vector( saved, c+1 )
                ], LINK_DELIM ) ];
            c -= STRIDE;
        } while ( c >= 0 );
    }

    c = llGetListLength( history ) - STRIDE;
    if ( c >= 0 ) {
        do {
            menuItems += llList2String( history, c );
            menuCommands += [ llDumpList2String( 
                [ "trvl", "tpto"
                , llList2Vector( history, c+1 )
                ], LINK_DELIM ) ];
            c -= STRIDE;
        } while ( c >= 0 );
    }
    
    llMessageLinked( menuPrim, NAV_MASK, 
        llDumpList2String( [ "menu", 
            "Teleport to:", 
            llList2CSV( menuItems ), 
            llList2CSV( menuCommands ) ],
            LINK_DELIM ),
        llGetOwner() );
}

save()
{
    string name = llList2String( llGetParcelDetails( llGetPos(), 
        [ PARCEL_DETAILS_NAME ] ), 0 );
    if ( llStringLength(name) > NAME_LENGTH ) {
        name = llGetSubString( name, 0, NAME_LENGTH );
    }
    saved += [ name, llGetRegionCorner() + llGetPos() ];
    llMessageLinked( LINK_ROOT, COMMUNICATION_MASK, 
        llDumpList2String( [ "IM", "Saved " + name ], LINK_DELIM ),
        llGetOwner() );
    trim_history();
}

integer plugPrim;

tpto( vector where )
{
    float power = llList2Float( llGetLinkPrimitiveParams( powerPrim,
        [ PRIM_COLOR, POWER_FACE ] ), 1 );
    if ( power <= 0.0 ) return;
    
    here = llGetPos() + llGetRegionCorner();
    inTransit = TRUE;
    
    llWhisper( powerChannel,
        llDumpList2String( 
            [ "play", "teleport start", 12.0, llGetOwner() ],
            CHAT_DELIM ) );
    llMessageLinked( LINK_SET, UI_MASK, 
        llDumpList2String( ["busy", 10.0], LINK_DELIM ),
        llGetOwner() );
    llSleep( 3.0 );
    llTriggerSound( teleportSound, 1.0 );
    float drain = llSqrt( llGetMass() ) * 10000.0;
    llMessageLinked( powerPrim, OBJ_MASK | (integer)drain, 
        "drain", llGetOwner() );
    llMessageLinked( rpPrim, RP_MASK,
        llDumpList2String( [ "act!", "a!fcs", TP_FOCUS ], LINK_DELIM )
        , llGetOwner() );
    llOwnerSay( llGetScriptName() + " has " + (string)llGetFreeMemory() + " bytes free." );
    llTeleportAgentGlobalCoords( llGetOwner(), where, 
        < (integer)where.x % 256,
            (integer)where.y % 256,
            (integer)where.z>,
        ZERO_VECTOR );
}

// -------------------------------------------------------------------------

load_landmarks()
{
    if ( llGetInventoryNumber( INVENTORY_LANDMARK ) ) {
        lmCount = 0;
        queryID = llRequestInventoryData( 
            llGetInventoryName( INVENTORY_LANDMARK, lmCount ) );
        llMessageLinked( LINK_ROOT, COMMUNICATION_MASK, 
            llDumpList2String(
                [ "restatus", "Hyperlight database ", 
                "updating...", 0 ], LINK_DELIM ), 
            llGetKey() );
    }
}

trim_history()
{
    integer max = MAX_LOCATIONS * STRIDE;
    if ( llGetListLength( history ) + llGetListLength( saved ) > 
        max )
    {
        if ( llGetListLength( saved ) > max ) {
            saved = llList2List( saved, -max, -1 );
        }
        history = llList2List( history, 
            -max + llGetListLength( saved ), -1 );
    }
    //llOwnerSay( llGetScriptName() + " now has " + (string)
    //    (( llGetListLength(history)+llGetListLength(saved) ) / STRIDE )
    //    + " stored locations of a max " + (string)MAX_LOCATIONS
    //    + "; " + (string)llGetFreeMemory() + " bytes free." );
}

// -------------------------------------------------------------------------

integer lmCount;
key queryID;

// -------------------------------------------------------------------------
// Landmark loading

integer rchrgHandle;                    // Listener for recharge

accept_landmark( string item )
{
    if ( llGetInventoryType( item ) != INVENTORY_NONE ) {
        llRemoveInventory( item );
    }
    llWhisper( powerChannel, 
        llDumpList2String( [ "load", "give", item ], CHAT_DELIM ) );
}

dump_all_items( integer type )
{
    integer c = llGetInventoryNumber( type );
    while ( --c >= 0 ) {
        llRemoveInventory( llGetInventoryName( type, c ) );
    }
}

// -------------------------------------------------------------------------

integer POWER_FACE = 1;
integer powerPrim;
integer rpPrim;
integer powerChannel;

integer get_power_channel( key id )
{
    return -1 * (integer)( "0x" + llGetSubString(id, -10, -3));
}

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

// -------------------------------------------------------------------------
// Configuration items
string notecard = "*Configuration";     // Notecard with configuration
key configQueryID;                      // Current query
integer noteLine;                       // Notecard line

// =========================================================================

default
{
    state_entry()
    {
        powerPrim = get_prim_named( "construct" );
        menuPrim = get_prim_named( "menu" );
        rpPrim = get_prim_named( "Act!" );
        plugPrim = get_prim_named( "options" );
        powerChannel = get_power_channel( llGetOwner() );
        if ( !noteLine ) {
            // Start reading configuration notecard
            configQueryID = llGetNotecardLine( notecard, noteLine );
        }
        load_landmarks();
        llSetTimerEvent( UPDATE_INTERVAL );
        if ( !( llGetPermissions() & PERMISSION_TELEPORT ) ) {
            llRequestPermissions( llGetOwner(), PERMISSION_TELEPORT );
        }
    }
    
    attach( key id )
    {
        if ( id != NULL_KEY ) {
           if ( !( llGetPermissions() & PERMISSION_TELEPORT ) ) {
                llRequestPermissions( id, PERMISSION_TELEPORT );
           }
        }
    }
    
    dataserver( key query, string data )
    {
        if ( query == queryID ) {
            string name = llGetSubString( 
                llGetInventoryName( INVENTORY_LANDMARK, lmCount ),
                0, NAME_LENGTH );
            integer i;
            if ( ( i = llListFindList( saved, [ name ] ) ) > -1 ) {
                saved = llDeleteSubList( saved, i, i+1 );
            }
            trim_history();
            saved = [ name, (vector)data + llGetRegionCorner() ] + saved;
            lmCount++;
            if ( lmCount < llGetInventoryNumber( INVENTORY_LANDMARK ) ) {
                queryID = llRequestInventoryData( 
                    llGetInventoryName( INVENTORY_LANDMARK, lmCount ) );
            } else {
                llMessageLinked( LINK_ROOT, COMMUNICATION_MASK, 
                    llDumpList2String(
                        [ "restatus", "Hyperlight database ", 
                        (string)( 
                           (integer)( 100 * llGetFreeMemory() / (64 * 1024) ) ) 
                        + "% full", 5.0 ], LINK_DELIM ), 
                    llGetKey() );
            }
        } else if ( query == configQueryID ) {
            if ( data != EOF ) {
                list keyval = llParseString2List( data, ["="], [] );
                string dataKey = llStringTrim( 
                        llToLower( llList2String( keyval, 0 ) ), 
                        STRING_TRIM );
                string dataVal = llStringTrim( 
                        llList2String( keyval, 1 ), 
                        STRING_TRIM );
                if ( llGetSubString( dataKey, 0, 1 ) != "//" ) {
                    if ( dataKey == "teleport sound" ) {
                        teleportSound = dataVal;
                    }
                }
                ++noteLine;
                configQueryID = llGetNotecardLine( notecard, noteLine );
            }
        }
    }
    
    changed( integer change )
    {
        if ( change & CHANGED_TELEPORT ) {
            if ( ! ( change & CHANGED_REGION ) ) llSleep( 0.25 );
            vector pos = llGetPos();
            string name = llList2String( llGetParcelDetails( pos, 
                    [ PARCEL_DETAILS_NAME ] ), 0 );

            // Add location to history
            name = llGetSubString( name, 0, NAME_LENGTH );
            list thisLoc = [ name, llGetRegionCorner() + pos ];
            if ( llListFindList( history + saved, [ name ] ) == -1 ) {
                history += thisLoc;
                trim_history();
            }
            last = here;
            here = pos + llGetRegionCorner();
            llSetTimerEvent( UPDATE_INTERVAL );
            
            if ( inTransit ) {
                pos += <1.0, 0., 0.> * llGetRot();
                llTriggerSound( teleportSound, 1.0 );
                llMessageLinked( LINK_SET, UI_MASK, 
                    llDumpList2String( ["busy", 5.0], LINK_DELIM ),
                    llGetOwner() );
                // Send position updates to team
                llMessageLinked( rpPrim, RP_MASK, 
                    llDumpList2String( [ "act!", "team", "tsay", "Follow " 
                        + llGetDisplayName( llGetOwner() ) + 
                        " to " + name + ": " +
                        " secondlife:///app/teleport/" +
                        llDumpList2String([llEscapeURL(llGetRegionName()), 
                            llRound(pos.x), llRound(pos.y), llRound(pos.z)],
                             "/") ]
                        , LINK_DELIM ), llGetOwner() );
                // Send position update to follower
                if ( trailURL ) {
                    llHTTPRequest( trailURL + "/" +
                        llDumpList2String( [ llRound( here.x ), 
                            llRound( here.y ), llRound( here.z ) ], "/" ),
                        [ HTTP_METHOD, "POST" ],
                        "" );
                    trailURL = "";
                }
            }
            inTransit = FALSE;
            if ( tpURL ) {
                llHTTPRequest( tpURL + "/" + llDumpList2String(
                    [ here.x, here.y, here.z ], "/" ),
                    [], "" );
                tpURL = "";
            }
            if ( llGetFreeMemory() < 512 ) {
                llWhisper( DEBUG_CHANNEL, llGetScriptName() + " using " +
                    (string)llGetUsedMemory() + " for " + 
                    (string)llGetListLength( history ) + 
                    " locations. Low memory." );
            }
        }
        if ( change & CHANGED_REGION ) {
            llMessageLinked( LINK_ALL_CHILDREN, BROADCAST_MASK, "region",
                llGetKey() );
        }
    }
    
    timer()
    {
        here = llGetPos() + llGetRegionCorner();
    }

    link_message( integer source, integer flag, string message, key id )
    {
        if ( flag & NAV_MASK ) {
            string cmd = llGetSubString( message, 0, 3 );
            
            //llOwnerSay( "[" + llGetScriptName() + ":ready:" + llKey2Name(id) + ":object]" + message );        
            
            if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "trvl" ) {
                nav_commands( llList2List(
                        llParseString2List( message, [ LINK_DELIM ], [] ),
                        1, -1 ) 
                    );
            } else if ( cmd == "load" ) {
                if ( llGetSubString( message, 5, -1 ) == "syn lm" ) {
                    state recharge;
                }
            } else if ( cmd == "trail" ) {
                trailURL = llGetSubString( message, 5, -1 );
            } else if ( cmd == "fmem" ) {
                llMessageLinked( source, llGetFreeMemory(), "fmem", id );
            } else if ( cmd == "diag" ) {
                llWhisper( 0, "/me TELEPORTER" +
                    "\n" + (string)llGetFreeMemory() + " bytes free."
                    + "\nSaved Locations: " + llList2CSV( saved )
                    );
            }
        }
    }
}
    
// =========================================================================
// Recharge; loading landmarks

state recharge
{
    state_entry()
    {
        dump_all_items( INVENTORY_LANDMARK );
        llAllowInventoryDrop( TRUE );
        rchrgHandle = llListen( powerChannel, "", NULL_KEY, "" );
        vector color = llList2Vector( llGetLinkPrimitiveParams( powerPrim,
            [ PRIM_COLOR, POWER_FACE ] ), 0 );
        integer band = (integer)( color.x * 0xFF ) & 0x1F;
        llWhisper( powerChannel, llDumpList2String( [ "load", "ack lm", band ], 
            CHAT_DELIM ) );
        llMessageLinked( LINK_ROOT, COMMUNICATION_MASK, 
            llDumpList2String(
                [ "restatus", "Hyperlight database ", 
                "loading...", 0 ], LINK_DELIM ), 
            llGetKey() );
    }
    
    on_rez( integer d )
    {
        llResetScript();
    }
    
    listen(integer channel, string name, key id, string m)
    {
        // llOwnerSay( llGetScriptName() + " heard " + m );
        
        list parsed = llParseString2List( m, [ CHAT_DELIM ], [] );
        string cmd = llList2String( parsed, 0 );
        
        if ( cmd == "load" ) {
            cmd = llList2String( parsed, 1 );
            if ( cmd == "offer lm" ) {
                accept_landmark( llList2String( parsed, 2 ) );
            } else if ( cmd == "fin lm" ) {
                state default;
            }
        }
    }
    
    state_exit()
    {
        llAllowInventoryDrop( FALSE );
        llListenRemove( rchrgHandle );
    }
}

// Copyright ©2013 Jack Abraham and player, all rights reserved
// Contact Guardian Karu in Second Life for distribution rights