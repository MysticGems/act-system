// =========================================================================
// Construct creator                                                       \
// By Jack Abraham                                                      \__
// =========================================================================

string readyItem;                       // Item ready to rez
integer userChannel;                    // HUD-construct control channel

// Rezzing aparameters
vector objOffset;                       // Offset from feet
rotation objRot;                        // Rotation relative to rezzer
vector DEFAULT_OFFSET = <1.5, 0., 0.>;  // Default object offset
rotation DEFAULT_ROT = ZERO_ROTATION;   // Default object rotation
list items;                             // Configured items

integer freeMem;                        // For tracking construct memory

integer camera = FALSE;                 // Rez relative to camera

integer camPermission = FALSE;          // Can track camera

integer powerPrim;                      // Prim where power levels are stored
integer POWER_FACE = 1;                 // Face where power levels are stored

integer rpPrim = LINK_SET;              // Prim for Act! data
integer SMF = 2;                        // Status, Morale, Focus
integer COMBAT_FACE = 6;                // Face where construct modifiers are
integer STUNNED = 0x2;                  // Act! stunned
integer DEFEATED = 0x8;                 // Act! defeated

integer NOTECARD_MASK = 0xFFFF0000;     // Split single integer for notecard
integer LINE_MASK = 0xFFFF;             // and line number

// -------------------------------------------------------------------------
// Commands processing

obj_commands( list msg, integer power, key id )
{
    string cmd = llList2String( msg, 0 );
    if ( cmd == "rez" ) {
        rez_object( llList2String( msg, 1 ), camera );
    } else if ( cmd == "camrez" ) {
        camera = !camera;
        set_prim_lit( camPrim, camera );
    } else if ( cmd == "load" ) {
        load( llList2String( msg, 1 ) );
    } else if ( cmd == "cool" ) {
        set_cooldown( llList2String( msg, 2 ), 
            (float)llList2String( msg, 1 ) );
    }
}

// -------------------------------------------------------------------------
// Rezzing functions

// ENERGY_MASK = 0x1F0; // Energy type (32 types, below)
integer BEAM_MASK = 0x40; // Generate beam & associated SFX
integer MYSTIC_GEMS = 0x80000000;       // Mystic Gems rezzer
integer PEACEKEEPER_MASK = 0x10000000;  // Rezzer was a peacekeeper model
integer PHANTOM_MASK = 0X80;            // Value for phantom constructs

//list ENERGY_TYPES =                     // Types of energy
//    [ "", "rage", "avarice", "fear", "will", "hope", "compassion", "love",
//    "death", "life", "light", "darkness", "sound", "force", "psi", "magic" ];

// Rez object
rez_object( string item, integer camera )
{
    // Check for focus
    vector smf = llList2Vector( llGetLinkPrimitiveParams( rpPrim,
        [ PRIM_COLOR, SMF ] ), 0 ) * 0xFF;
    if ( smf.z < 1.0 ) {
       llMessageLinked( LINK_ROOT, COMM_MASK, 
            llDumpList2String( 
                [ "IM", "No focus." ], 
                LINK_MSG_DELIM ),
            llGetOwner() );
        return;
    }
    integer actFlags = (integer)smf.x;
    if ( actFlags & ( STUNNED | DEFEATED ) ) {
       llMessageLinked( LINK_ROOT, COMM_MASK, 
            llDumpList2String( 
                [ "IM", "Can't use powers while stunned." ], 
                LINK_MSG_DELIM ),
            llGetOwner() );
        return;
    }

    list powerProperties = llGetLinkPrimitiveParams( powerPrim,
        [ PRIM_COLOR, POWER_FACE ] );
    float powerLevel = (float)llLinksetDataRead( "power" );
    vector powerAttrib = llList2Vector( powerProperties, 0 ) * 0xFF;
    
    // Check for power remaining
    if ( powerLevel <= 0.0 ) {
        llMessageLinked( LINK_ROOT, COMM_MASK, 
            llDumpList2String( 
                [ "IM", "Power exhausted." ], 
                LINK_MSG_DELIM ),
            llGetOwner() );
        return;
    }
    if ( !check_perms() ) {
        llMessageLinked( LINK_ROOT, COMM_MASK, 
            llDumpList2String( 
                [ "IM", "Constructs inhibited by parcel" ], 
                LINK_MSG_DELIM ),
            llGetOwner() );
        return;
    }
    if ( in_cooldown( item ) ) {
        llMessageLinked( LINK_ROOT, COMM_MASK, 
            llDumpList2String( 
                [ "IM", "Construct in cooldown" ], 
                LINK_MSG_DELIM ),
            llGetOwner() );
        return;
    }
    
    rotation rot;
    vector pos;
    integer madeOf = (integer)(powerAttrib.x);
    integer params = (integer)(powerAttrib.y);
    if ( camera && ( llGetPermissions() & PERMISSION_TRACK_CAMERA ) ) {
        // If Using camera, get posiiton and rotation from camera
        rot = objRot * get_leveled_rot( llGetCameraRot() );
        pos = llGetCameraPos()  +
            ( ( <3.5, 0.0, -2.0> + objOffset )  * llGetCameraRot() );
        if ( llVecDist( pos, llGetPos() ) > 10.0 ) {
            llMessageLinked( LINK_ROOT, COMM_MASK, 
                llDumpList2String( 
                    [ "IM", "Out of range." ], 
                    LINK_MSG_DELIM ),
                llGetOwner() );
            return;
        }
    } else {
        // Otherwise use the agent's rotation (NOT the prim; this can be
        // a child prim)
        list details = llGetObjectDetails( llGetOwner(),
            [ OBJECT_ROT, OBJECT_POS ] );
        rot = llList2Rot( details, 0 ); 
        pos = llList2Vector( details, 1 ) + ( objOffset * rot );
        rot = objRot * get_leveled_rot( rot );
        // Offset to avatar's feet
        list bbox = llGetBoundingBox( llGetOwner() );
        vector size = llList2Vector( bbox, 1 ) 
            - llList2Vector( bbox, 0 );
        pos += <0., 0., -size.z * 0.5>;
    }
    
    // Get Act! modifiers
    vector rpAttrib = llList2Vector( llGetLinkPrimitiveParams( rpPrim,
        [ PRIM_COLOR, COMBAT_FACE ] ), 0 ) * 0xFF;
    integer damageMod = (integer)rpAttrib.x & 0xF;
    integer DBmod = (integer)rpAttrib.y & 0xF;
    integer conditions = (integer)rpAttrib.z;

    integer rezParam = MYSTIC_GEMS | madeOf | BEAM_MASK |
        params << 24 |  conditions << 8 | DBmod << 16 | damageMod << 20;
    //llOwnerSay( llGetScriptName() + " Conditions = " + (string)conditions +
    //    "; composition = " + (string)( rezParam & 0x3F )
    //    + "; hue = " + (string)( rezParam & 0xF000000 ) );
    // Rez object
    llRezAtRoot( item, pos, ZERO_VECTOR, rot, rezParam );
    llSetTimerEvent( 1.0 );
}

integer check_scripts( integer flags ) {
    if ( flags & PARCEL_FLAG_ALLOW_SCRIPTS )
        return TRUE;
    else if ( flags & PARCEL_FLAG_ALLOW_GROUP_SCRIPTS ) {
        key parcelGroup = llList2Key( 
                llGetParcelDetails( llGetPos(), [ PARCEL_DETAILS_GROUP ] )
                , 0 );
        key group = llList2Key(
            llGetObjectDetails( llGetKey(), [ OBJECT_GROUP ] )
            , 0 );
        if ( parcelGroup == group ) {
            return TRUE;
        }
    } 
    vector here = llGetPos();
    if ( llGround( here ) < here.z - 50.0 ) {
        return TRUE;
    }
    return FALSE;
}

integer check_perms() {
    if ( llGetParcelMaxPrims( llGetPos(), TRUE ) 
        - llGetParcelPrimCount( llGetPos(), PARCEL_COUNT_TOTAL, TRUE ) < 0 )
    {
        llMessageLinked( LINK_ROOT, COMM_MASK, 
            llDumpList2String( 
                [ "IM", "No free land capacity." ], 
                LINK_MSG_DELIM ),
            llGetOwner() );
    }
    if ( llOverMyLand( llGetOwner() ) ) return TRUE;

    integer parcel = llGetParcelFlags( llGetPos() );

    if ( !check_scripts( parcel ) ) return FALSE;

    if ( PARCEL_FLAG_ALLOW_CREATE_OBJECTS  & parcel )
        return TRUE;
    else if ( PARCEL_FLAG_ALLOW_CREATE_GROUP_OBJECTS & parcel ) {
        key parcelGroup = llList2Key( 
                llGetParcelDetails( llGetPos(), [ PARCEL_DETAILS_GROUP ] )
                , 0 );
        key group = llList2Key(
            llGetObjectDetails( llGetKey(), [ OBJECT_GROUP ] )
            , 0 );
        if ( parcelGroup == group ) {
            return TRUE;
        }
    }
    return FALSE;
}

load( string object )
{
    readyItem = object;
    if ( llGetInventoryType( readyItem ) != INVENTORY_OBJECT ) {
        readyItem = "";
        llMessageLinked( LINK_ROOT, COMM_MASK, 
            llDumpList2String( 
                [ "IM", "Unable to conceptualize construct." ], 
                LINK_MSG_DELIM ),
            llGetOwner() );
    } else {
        integer i = llListFindList( items, [ readyItem ] );
        if ( i > -1 ) {
            integer index = llList2Integer( items, i + 1 );
            queryID = llGetNotecardLine( 
                llGetInventoryName( INVENTORY_NOTECARD, index >>  16 ), 
                index & LINE_MASK );
        } else {
            objOffset = DEFAULT_OFFSET;
            objRot = DEFAULT_ROT;
            rez_object( readyItem, camera );
        }
    }
}

// Function posted to the SL Scripting Tips forum by Hewee Zetkin
// Returns a rotation for an orientation facing "in the same direction"
// horizontally as the argument, but with the local and global z axes aligned.
rotation get_leveled_rot(rotation rot)
{
   vector resultFwd;
   vector resultLeft;

   vector fwd = llRot2Fwd(rot);
   if (1.0-fwd.z < 0.001)
   {
      // we're looking straight up, so do the intuitive thing and base
      // the answer on which way our "down" is pointing (if we pitched down
      // to horizontal, that's the direction we'd be facing).

      vector left = llRot2Left(rot);
      resultLeft = llVecNorm(<left.x, left.y, 0.0>);
      resultFwd = <resultLeft.y, -resultLeft.x, 0.0>; // resultLeft % <0,0,1>
   } else {
      resultFwd = llVecNorm(<fwd.x, fwd.y, 0.0>);
      resultLeft = <-resultFwd.y, resultFwd.x, 0.0>; // <0,0,1> % resultFwd
   }

   return llAxes2Rot(resultFwd, resultLeft, <0.0, 0.0, 1.0>);
}

// -------------------------------------------------------------------------
// Cooldown

list cooldown;                          // Constructs in cooldown
list hotbuttons;                        // Hot button prims

set_cooldown( string construct, float time )
{
    trim_cooldown();
    if ( llGetInventoryType( construct ) != INVENTORY_OBJECT ) return;
    if ( llGetListLength( cooldown ) >= 20 ) {
        cooldown = llDeleteSubList( cooldown, -19, -1);
    }
    cooldown += [ construct, llGetTime() + time ];
    set_hotbutton( construct, TRUE );
}

integer in_cooldown( string construct )
{
    trim_cooldown();
    integer i = llListFindList( cooldown, [ construct ] );
    return i > -1;
}

trim_cooldown()
{
    if ( cooldown ) {
        integer c = llGetListLength( cooldown ) - 1;
        float now = llGetTime();
        while ( c > 0 ) {
            if ( llList2Float( cooldown, c ) < now ) {
                string item =  llList2String( cooldown, c-1 );
                set_hotbutton( item, FALSE );
                llOwnerSay( item + " ready." );
                cooldown = llDeleteSubList( cooldown, c - 1, c );
            }
            c -= 2;
        }
    }
}

set_hotbutton( string item, integer dim ) {
    item = "objt^rez^" + item;
    integer c = llGetListLength( hotbuttons );
    string desc;
    integer prim;
    while( --c > -1 ) {
        prim = llList2Integer( hotbuttons, c );
        desc = llList2String( llGetLinkPrimitiveParams( prim, 
            [PRIM_DESC] ), 0 );
        if ( desc == item ) {
            if ( dim ) {
                llSetLinkPrimitiveParamsFast( prim, [ PRIM_COLOR, 0,
                    <1, 1, 1>, 0.5 ] );
            } else {
                llSetLinkPrimitiveParamsFast( prim, [ PRIM_COLOR, 0,
                    <1, 1, 1>, 1.0 ] );
            }
            return;
        }
    }
}

integer LIT_FACE = 0;
integer DIM_FACE = 2;

set_prim_lit( integer prim, integer lit )
{
    if ( prim < 1 ) return;
    if ( lit ) {
        llSetLinkColor( prim, 
            llList2Vector( 
                llGetLinkPrimitiveParams( LINK_ROOT, 
                    [ PRIM_COLOR, LIT_FACE ] )
                , 0 ), 
            ALL_SIDES );
    } else {
        llSetLinkColor( prim, 
            llList2Vector( 
                llGetLinkPrimitiveParams( LINK_ROOT, 
                    [ PRIM_COLOR, DIM_FACE ] )
                , 0 ), 
            ALL_SIDES );
    }
}

// -------------------------------------------------------------------------

integer menuPrim = LINK_SET;
integer statusPrim = LINK_ROOT;
integer camPrim = 0;

list get_link_numbers_for_names(list namesToLookFor)
{
    list linkNumbers = namesToLookFor;
    integer f = llGetNumberOfPrims();
    integer pos = -1;
    do {
        pos = llListFindList(namesToLookFor, [llGetLinkName(f)]);
        if (pos > -1) {
            linkNumbers = llListReplaceList(linkNumbers, [f], pos, pos);
        }
    } while (--f > 0);
    return linkNumbers;
}

integer key2channel( key id )
{
    return -1 * (integer)( "0x" + llGetSubString(id, -10, -3));
}

request_permissions()
{
    llRequestPermissions( llGetOwner(), 
        llGetPermissions() 
        | PERMISSION_TRACK_CAMERA
        | PERMISSION_TRIGGER_ANIMATION );
}

// -------------------------------------------------------------------------
// Notecard reading

string constrNote = "*Constructs";      // Constructs notecard
key queryID;                            // Current query
integer notecard;                       // Notecard being read
integer noteLine;                       // Notecard line
string NOTE_DELIM = "|";                // Notecard field delimiter

// -------------------------------------------------------------------------
// Construct loading

integer rchrgHandle;                    // Listener for recharge

accept_item( string item )
{
    if ( llGetInventoryType( item ) != INVENTORY_NONE ) {
        llRemoveInventory( item );
    }
    llWhisper( userChannel, 
        llDumpList2String( [ "load", "give", item ], CHAT_MSG_DELIM ) );
}

dump_all_items( integer type )
{
    integer c = llGetInventoryNumber( type );
    while ( --c >= 0 ) {
        llRemoveInventory( llGetInventoryName( type, c ) );
    }
}

// -------------------------------------------------------------------------

string LINK_MSG_DELIM = "§";
string CHAT_MSG_DELIM = "|";

integer BROADCAST_MASK      = 0xFFF00000;
integer OBJ_MASK            = 0x2000000;
integer COMM_MASK           = 0x10000000;
integer UI_MASK             = 0x80000000;
integer RP_MASK             = 0x4000000;

integer POWER_LEVEL_MASK    = 0xF;

// =========================================================================
// Configuring

default
{
    state_entry()
    {
        freeMem = llGetFreeMemory();
        list prims = get_link_numbers_for_names( [ "objt^camrez", "Act!",
            "construct" ] );
        camPrim = llList2Integer( prims, 0 );
        rpPrim = llList2Integer( prims, 1 );
        powerPrim = llList2Integer( prims, 2 );
        hotbuttons = get_link_numbers_for_names( [ "hot1", "hot2", "hot3",
            "hot4", "hot5", "hot6", "hot7", "hot8", "hot9", "hot0" ] );
        set_prim_lit( camPrim, FALSE );
        userChannel = key2channel( llGetOwner() );
        if ( llGetInventoryNumber( INVENTORY_NOTECARD ) ) {
            noteLine = 0;
            notecard = 0;
            queryID = llGetNotecardLine( 
                llGetInventoryName( INVENTORY_NOTECARD, notecard ), 
                noteLine );
            llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String(
                [ "restatus", "Constructs: ", "Configuring...", 5 ], 
                    LINK_MSG_DELIM ), 
                llGetKey() );
            llMessageLinked( LINK_THIS, OBJ_MASK, llDumpList2String(
                [ "objt", "refresh" ], LINK_MSG_DELIM ), llGetKey() );
        } else {
            llOwnerSay( "Construct system failure; charge your ring." );
            llLinksetDataWrite( "power", (string)0.0 );
            state error;
        }
        if ( llGetAttached() ) {
            request_permissions();
        }
    }
    
    attach( key id )
    {
        if ( id ) {
            request_permissions();
            cooldown = [];
        }
    }
    
    dataserver( key query, string data )
    {
        if ( query == queryID ) {
            if ( data != EOF ) {
                list parsed = llParseString2List( data, [ NOTE_DELIM ], 
                    [] );
                if ( llGetInventoryType( llList2String( parsed, 0 ) ) ==
                    INVENTORY_OBJECT )
                {
                    items += [ llList2String( parsed, 0 ), notecard << 16
                       | noteLine ];
                    //llOwnerSay( "Configured " +  
                    //    llGetInventoryName( INVENTORY_NOTECARD, notecard ) 
                    //    + "/" 
                    //    + llList2String( parsed, 0 ) );
                }
                ++noteLine;
                queryID = llGetNotecardLine( 
                    llGetInventoryName( INVENTORY_NOTECARD, notecard ),
                    noteLine );
            } else {
                if ( ++notecard >= llGetInventoryNumber( INVENTORY_NOTECARD ) )
                {
                    state active;
                } else {
                    noteLine = 0;
                    queryID = llGetNotecardLine( 
                        llGetInventoryName( INVENTORY_NOTECARD, notecard ),
                        noteLine );
                }
            }
        }
    }
    
    link_message( integer source, integer flag, string message, key id )
    {
        if ( flag & OBJ_MASK ) {
            string cmd = llGetSubString( message, 0, 3 );
            
            //llOwnerSay( "[" + (string)this + ":" + (string)source + ":" + llKey2Name(id) + ":object]" + message );        
            
            if ( cmd == "rset" ) {
                llResetScript();
            }
        }
    }
    
}

// ------------------------------------------------------------------------
// Something went wrong reading configuration.  Try again on any excuse.

state error
{
    state_entry()
    {
        //llOwnerSay( "Construct configuration failure." );
    }    

    attach( key id )
    {
        llResetScript();
    }
    
    changed( integer change )
    {
        if ( change & ( CHANGED_INVENTORY | CHANGED_ALLOWED_DROP ) ) {
            llResetScript();
        }
    }
    
    link_message( integer source, integer flag, string message, key id )
    {
        if ( flag & OBJ_MASK ) {
            string cmd = llGetSubString( message, 0, 3 );
            
            //llOwnerSay( "[" + llGetScriptName() + ":" + (string)source + ":" + llKey2Name(id) + ":error]" + cmd + ":" + llGetSubString( message, 5, -1 ) );        
            
            if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "load" ) {
                if ( llGetSubString( message, 5, -1 ) == "syn" ) {
                    if ( llGetOwnerKey( id ) == llGetOwner() ) {
                        state recharge;
                    }
                }
            }
        }
    }
    
}

// ========================================================================
// Ready to rez constructs

state active
{
    state_entry()
    {
        if ( llGetAttached() ) {
            request_permissions();
        }
        llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String( [ "restatus",
            "Constructs: ", 
                (string)( (integer)( 100 * llGetFreeMemory() / freeMem ) )
                + "% free", 5 ], LINK_MSG_DELIM ), llGetKey() );
        //llWhisper( DEBUG_CHANNEL, "/me system initialized; " 
        //    + (string)( (integer)( 100 * llGetFreeMemory() / freeMem ) ) 
        //    + "% capacity (" + (string)llGetFreeMemory()
        //    + " bytes) remaining with " 
        //    + (string)( llGetListLength( items ) / 2 )
        //    + " configured constructs; " 
        //    + (string)llGetInventoryNumber( INVENTORY_OBJECT )
        //    + " constructs loaded." );
        if ( cooldown != [] ) {
            llSetTimerEvent( 1.0 );
        }
    }
    
    attach( key id )
    {
        if ( id ) {
            request_permissions();
        }
    }
    
    dataserver( key query, string data )
    {
        if ( query == queryID ) {
            list parsed = llParseString2List( data, [ NOTE_DELIM ], 
                [] );
            objOffset = (vector)llList2String( parsed, 1 );
            objRot = llEuler2Rot( 
                (vector)llList2String( parsed, 2 ) * DEG_TO_RAD );
            //llOwnerSay( llGetScriptName() +
            //    "read item " + llList2String( parsed, 0 )
            //    + " offset " + (string)objOffset + " & rotation "
            //    + (string)( llRot2Euler( objRot ) * RAD_TO_DEG ) );
            rez_object( readyItem, camera );
        }
    }
    
    link_message( integer source, integer flag, string message, key id )
    {
        if ( flag & OBJ_MASK ) {
            string cmd = llGetSubString( message, 0, 3 );
            
            // llOwnerSay( "[" + llGetScriptName() + ":" + (string)source + ":" + llKey2Name(id) + ":object]" + message );        
            
            if ( cmd == "objt" )
            {
                list msg = llParseString2List( message, 
                    [LINK_MSG_DELIM], [] );
                obj_commands( llList2List( msg, 1, -1 ), 
                    flag & POWER_LEVEL_MASK, id );
            } else if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "load" ) {
                if ( llGetSubString( message, 5, -1 ) == "syn" ) {
                    if ( llGetOwnerKey( id ) == llGetOwner() ) {
                        state recharge;
                    }
                }
            } else if ( cmd == "fmem" ) {
                llMessageLinked( source, llGetFreeMemory(), "fmem", id );
            } else if ( cmd == "diag" ) {
                llWhisper( 0, "/me CONSTRUCT CREATOR\n"
                    + (string)( (integer)( 100 * llGetFreeMemory() / freeMem ) ) 
                    + "% capacity (" + (string)llGetFreeMemory()
                    + " bytes) remaining with " 
                    + (string)( llGetListLength( items ) / 2 )
                    + " configured constructs; " 
                    + (string)llGetInventoryNumber( INVENTORY_OBJECT )
                    + " constructs loaded."
                    + "\nReady Item: " + readyItem
                    );
            }
        }
    }
    
    timer()
    {
        trim_cooldown();
        if ( cooldown == [] ) {
            llSetTimerEvent( 0. );
        }
    }
    
    state_exit()
    {
        llSetTimerEvent( 0. );
    }
}

// =========================================================================
// Recharge; loading constructs

state recharge
{
    state_entry()
    {
        llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String(
            [ "restatus", "Constructs: ", "Loading...", 0 ], 
                LINK_MSG_DELIM ), 
            llGetKey() );
        dump_all_items( INVENTORY_OBJECT );
        dump_all_items( INVENTORY_NOTECARD );
        llAllowInventoryDrop( TRUE );
        rchrgHandle = llListen( userChannel, "", NULL_KEY, "" );
        vector color = llList2Vector( llGetLinkPrimitiveParams( powerPrim,
            [ PRIM_COLOR, POWER_FACE ] ), 0 );
        integer band = (integer)( color.x * 0xFF );
        llWhisper( userChannel, llDumpList2String( [ "load", "ack", band & 0x1F ], 
            CHAT_MSG_DELIM ) );
        llSleep( 0.5 );
    }
    
    on_rez( integer d )
    {
        llResetScript();
    }
    
    listen(integer channel, string name, key id, string m)
    {
        //llOwnerSay( llGetScriptName() + " heard " + m );
        
        list parsed = llParseString2List( m, [ CHAT_MSG_DELIM ], [] );
        string cmd = llList2String( parsed, 0 );
        
        if ( cmd == "load" ) {
            cmd = llList2String( parsed, 1 );
            if ( cmd == "offer" ) {
                accept_item( llList2String( parsed, 2 ) );
            } else if ( cmd == "fin" ) {
                llAllowInventoryDrop( FALSE );
                llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String(
                    [ "unstatus", "Loading Construct" ], LINK_MSG_DELIM ), 
                    llGetKey() );
                llResetScript();
            }
        }
    }

    link_message( integer source, integer flag, string message, key id )
    {
        if ( flag & OBJ_MASK ) {
            string cmd = llGetSubString( message, 0, 3 );
            
            // llOwnerSay( "[" + llGetScriptName() + ":" + (string)source + ":" + llKey2Name(id) + ":object]" + message );        
            
            if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "diag" ) {
                llWhisper( 0, "/me CONSTRUCT CREATOR\n"
                    + "Stuck in recharge; reset the HUD."
                    );
            }
        }
    }
}

// Copyright ©2023 Jack Abraham and player, all rights reserved
// Contact Guardian Karu in Second Life for distribution rights