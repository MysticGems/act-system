// ===========================================================================
// Target Pointer                                                            \
// By Jack Abraham                                                        \__
// ===========================================================================

rotation hudRot;                        // Base rotation; N at top of HUD;
                                        //      Be sure x=0° for this
float last_bearing;                     // Last bearing we were on
float last_facing;
float last_bearing_change;              // Last time we changed bearing
float last_facing_change;
float last_range;                       // Last range to target
integer change_bearing = FALSE;         // Is a bearing change pending
integer change_facing = FALSE;          // Is facing change pending
key owner;                              // HUD owner
key target;                             // What we're tracking
vector color;                           // Tracking bar color

integer LIT_FACE = 0;                   // Root face with lit color
float LONG_TIME = 5.0;
float SHORT_TIME = 1.0;
float VERY_SHORT_TIME = 0.2;
integer CONTROLS;

integer actHandle;                      // Handle for Act! listener
string ACT_HEADER = "a!smf:";
string rlv;

string status = "";

integer targetDisplay;
integer targetProbe;
integer compassPrim;
integer moralePrim;
integer focusPrim;

rotation compassRot;

integer RLV_CHANNEL = -1812221819;      // Channel for RLV ping
integer RLV_RESPONSE = 182040672;
integer rlvHandle;                      // RLV listener handle

string SOLID =   "▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮";
string HOLLOW =  "▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯";
string SPACER =  "                            ";
integer MAX_TICKS = 15;
vector MORALE_COLOR = <0.3333, 1.0, 0.3333>;
vector FOCUS_COLOR = <0.0, 0.6667, 1.0>;

string MINIBAR = "_▂▄▆█";

integer PEACE_MASK = 0x08;
integer STUNNED_MASK = 0x2;
integer RESTRAINED_MASK = 0x4;
integer DEFEATED_MASK = 0x8;
integer WOUNDED_MASK = 0x10;
integer VULNERABLE_MASK = 0x80;

check_bearing( key target ) {
    if ( target == NULL_KEY ) return;
    rotation myRot = llGetCameraRot();
    vector myPos = llGetCameraPos();
    list details = llGetObjectDetails( target, [ OBJECT_POS ] );
    if ( details == [] ) {
        llMessageLinked( LINK_SET, llGetLinkNumber() * 1000,
            "targeting§" + (string)NULL_KEY, llGetOwner() );
        state default;
    }
    vector hisPos = llList2Vector( details, 0 );
    vector offset = llVecNorm( hisPos - myPos ) / myRot;
    float range = llVecMag( hisPos - llGetPos() );
    
    offset = llVecNorm( offset );
    
    float bearing = llAtan2( offset.x, offset.y );

    if ( bearing < 0. ) bearing += TWO_PI;
    if ( ( bearing != last_bearing ) || ( range != last_range) ) {
        change_bearing = TRUE;
        last_bearing = bearing;
        last_range = range;
        last_bearing_change = llGetTime();
        llSetTimerEvent( VERY_SHORT_TIME );
    } else if ( llGetAgentInfo( owner ) & AGENT_MOUSELOOK ) {
        llSetTimerEvent( VERY_SHORT_TIME );
    }
}

check_facing(){
    rotation rot = llGetCameraRot();
    vector fwd = llRot2Fwd( rot );
    float bearing = llAtan2( fwd.y, fwd.x );
    if ( llFabs( fwd.z > 0.999 ) ) {
        vector left = llRot2Left( rot );
        bearing = llAtan2( -left.x, left.y );
    }
    if ( bearing < 0. ) bearing += TWO_PI;
    if ( bearing != last_facing ) {
        change_facing = TRUE;
        last_facing = bearing;
        last_facing_change = llGetTime();
        llSetTimerEvent( VERY_SHORT_TIME );
    } else if ( llGetAgentInfo( owner ) & AGENT_MOUSELOOK ) {
        llSetTimerEvent( VERY_SHORT_TIME );
    }
}

string compass (vector target, vector loc) 
{
    float distance = llVecDist(loc, target);
    float angle = 0.;
    if ( distance ){
        angle = llAtan2( ( target.x-loc.x ) / distance, 
            ( target.y-loc.y ) / distance ) * RAD_TO_DEG;
    }
    if ( angle < 0. )
        angle += 360.;
    if ( angle < 22.5 )
        return "N";
    else if ( angle < 67.5 )
        return "NE";
    else if ( angle < 112.5 )
        return "E";
    else if ( angle < 157.5 )
        return "SE";
    else if ( angle < 202.5 )
        return "S";
    else if ( angle < 247.5 )
        return "SW";
    else if ( angle < 292.5 )
        return "W";
    else if ( angle < 337.5 )
        return "NW";
    else
        return "N";
}
set_bar_level( float current, float attrib, integer prim, vector color, 
    integer line )
{
    string bar;
    float ratio;
    float maximum;
    
    if ( current < 0 ) current = 0.0;
    if ( attrib > 0 ) {
        ratio = current / attrib;
    }
    if ( ratio > 1.0 ) ratio = 1.0;
    integer level = (integer)( ratio * (float)MAX_TICKS );
    if ( level ) {
        bar = llGetSubString( SOLID, 0, level - 1 );
    }
    if ( level < MAX_TICKS ) {
        bar += llGetSubString( HOLLOW, 0, MAX_TICKS - level - 1 );
    }
    if ( line ) bar = bar + SPACER;
    else bar = SPACER + bar;
    llSetLinkPrimitiveParamsFast( prim, [ PRIM_TEXT, bar, color, 1.0 ] );
}

set_text( string text )
{
    if ( text ) {
        llSetLinkPrimitiveParamsFast( targetDisplay, 
            [ PRIM_TEXT, text, color, 1.0] );
    } else {
        llSetLinkPrimitiveParamsFast( targetDisplay, 
            [ PRIM_TEXT, text, color, 1.0 ] );
    }
}

list get_link_numbers ( list names )
{
    integer c = llGetNumberOfPrims() + 1;
    integer i = -1;
    while ( c-- >= 0 ) {
        i = llListFindList( names, [ llGetLinkName( c ) ] );
        if ( i > -1 ) {
            names = llListReplaceList( names, [c], i, i );
        }
    }
    return names;
}

integer key2channel( key who ) {
    return -1 * (integer)( "0x" + llGetSubString( (string)who, -12, -5 ) );
}

rlv_ping()
{
    rlv = "";
    rlvHandle = llListen( RLV_RESPONSE, "", NULL_KEY, "" );
    llRegionSay( RLV_CHANNEL, "Ping," + (string)target + ",@version="
        + (string)RLV_RESPONSE );
}

default
{
    state_entry()
    {
        hudRot = llEuler2Rot( <PI_BY_TWO, 0., 0. > );
        llSetRot( hudRot );
        compassRot = llEuler2Rot( <0., 0, -PI_BY_TWO> );
        owner = llGetOwner();
        target = NULL_KEY;
        llSetAlpha( 0.0, ALL_SIDES );
        llSetTimerEvent( 0. );
        list prims = get_link_numbers( ["target display",     
                "sens^probe", "sensors", "compass", "target morale",
                "target focus" ] );
        targetDisplay = llList2Integer( prims, 0 );
        targetProbe = llList2Integer( prims, 1 );
        compassPrim = llList2Integer( prims, 3 );
        moralePrim = llList2Integer( prims, 4 );
        focusPrim = llList2Integer( prims, 5 );
        
        last_range = 0.;
        
        CONTROLS = 
            CONTROL_FWD | CONTROL_BACK | CONTROL_ROT_LEFT | 
            CONTROL_ROT_RIGHT | CONTROL_UP | CONTROL_DOWN;
        if ( llGetAttached() ) {
            llRequestPermissions( llGetOwner(), 
                PERMISSION_TAKE_CONTROLS | PERMISSION_TRACK_CAMERA );
        }
        set_text( "" );
        llSetLinkPrimitiveParamsFast( moralePrim, 
            [ PRIM_TEXT, "", ZERO_VECTOR, 0.0 ] );
        llSetLinkPrimitiveParamsFast( focusPrim, 
            [ PRIM_TEXT, "", ZERO_VECTOR, 0.0 ] );
        llSetObjectDesc( (string)NULL_KEY );
        llSetLinkPrimitiveParamsFast( targetProbe,
            [ PRIM_COLOR, ALL_SIDES, <0, 0, 0>, 0.0 ] );
        llSetTimerEvent( SHORT_TIME );
    }

    on_rez( integer p )
    {
        llResetScript();
    }
    
    run_time_permissions( integer perms )
    {
        if ( perms & PERMISSION_TAKE_CONTROLS )
        {
            llTakeControls( CONTROLS, FALSE, TRUE );
        }
    }

    link_message( integer source, integer val, string m, key id )
    {
        list parsed = llParseString2List( m, [ "§" ], [] );
        string cmd = llList2String( parsed, 0 );
        
        // llOwnerSay( llGetLinkName( source ) );
        
        if ( cmd == "trgt" ) {
            target = (key)llList2String( parsed, 1 );
            llSetObjectDesc( (string)target );
            if ( target ) {
                state tracking;
            }
        } else if ( cmd == "rset" ) {
            llResetScript();
        }
    }
    
    timer()
    {
        float now = llGetTime();
        if ( now - last_facing_change > LONG_TIME  ) {
            if ( ! ( llGetAgentInfo( owner ) & AGENT_MOUSELOOK ) ) {
                llSetTimerEvent( VERY_SHORT_TIME );
            }
        }
        check_facing();
        if ( change_facing ) {
            // llRotateTexture( last_bearing + PI, ALL_SIDES );
            llSetLinkPrimitiveParamsFast( compassPrim, [ PRIM_ROT_LOCAL,
                llEuler2Rot( <0., 0., -last_facing> ) * compassRot ] );
            change_facing = FALSE;
        }
    }
}

state tracking
{
    state_entry()
    {
        if ( target == NULL_KEY ) {
            state default;
        }
        llSetTimerEvent( SHORT_TIME );
        llSetAlpha( 0.5, ALL_SIDES );
        check_bearing( target );
        color = llList2Vector( llGetLinkPrimitiveParams( LINK_ROOT,
            [ PRIM_COLOR, LIT_FACE ] ), 0 );
        llSetLinkPrimitiveParamsFast( targetProbe,
            [ PRIM_COLOR, ALL_SIDES, <0, 0, 0>, 0.4 ] );
            
        // Get Act! status, if present
        integer channel = key2channel( target );
        if ( channel ) {
            actHandle = llListen( channel, "", NULL_KEY, "" );
            llRegionSay( channel, (string)target + ":a!png" );
            rlv = "";
            status = "";
            if ( llGetAgentSize( target ) ) {
                llSensorRepeat( "", target, AGENT, 20.0, PI, 5.0 );
            }
        } else {
            target = NULL_KEY;
            state default;
        }
    }
    
    sensor( integer d )
    {
        rlv_ping();
        llSensorRemove();
    }
    
    listen( integer channel, string who, key id, string msg )
    {
        if ( llGetSubString( msg, 0, 5 ) == ACT_HEADER ) {
            if ( llGetOwnerKey( id ) == target || id == target ) {
                msg = llGetSubString( msg, 6, -1 );
                list parsed = llParseString2List( msg, [":"], [] );
                vector rdi = (vector)llList2String( parsed, 1 );
                vector srp = (vector)llList2String( parsed, 0 );
                vector def = (vector)llList2String( parsed, 2 );
                vector needs = (vector)llList2String( parsed, 5 );
                if ( !( (integer)def.z & PEACE_MASK ) ) {
                    set_bar_level( srp.y, rdi.y + rdi.x,
                        moralePrim, MORALE_COLOR, 1 ); 
                    set_bar_level( srp.z, rdi.y + rdi.z,
                        focusPrim, FOCUS_COLOR, 0 ); 
                } else {
                    llSetLinkPrimitiveParamsFast( moralePrim, 
                        [ PRIM_TEXT, "", ZERO_VECTOR, 0.0 ] );
                    llSetLinkPrimitiveParamsFast( focusPrim, 
                        [ PRIM_TEXT, "", ZERO_VECTOR, 0.0 ] );
                }
                integer states = (integer)srp.x;
                list statusItems = [];
                if ( states & STUNNED_MASK ) {
                    statusItems += "⊘";
                }
                if ( states & WOUNDED_MASK ) {
                    statusItems += "♥";
                }
                if ( states & RESTRAINED_MASK ) {
                    statusItems += "◉";
                }
                if ( states & VULNERABLE_MASK ) {
                    statusItems += "‼";
                }
                if ( needs.y > 0.0 ) {
                    integer arousal = llRound( 4.0 * 
                        needs.y / ( rdi.x + rdi.z ) 
                        );
                    statusItems += "⚤" + 
                        llGetSubString( MINIBAR, arousal, arousal );
                }
                status = llDumpList2String( statusItems, " " );
            }
        } else if ( llGetSubString( msg, 0, 9 ) == "Restrained" ) {
            rlv = "❖";
        }
    }

    on_rez( integer p )
    {
        llResetScript();
    }
    
    control( key av, integer held, integer change )
    {
        if ( held && !change_bearing ) {
            check_bearing( target );
        }
    }

    run_time_permissions( integer perms )
    {
        if ( perms & PERMISSION_TAKE_CONTROLS )
        {
            llTakeControls( CONTROLS, FALSE, TRUE );
        }
    }

    link_message( integer source, integer val, string m, key id )
    {
        list parsed = llParseString2List( m, [ "§" ], [] );
        string cmd = llList2String( parsed, 0 );
        
        // llOwnerSay( m );
        
        if ( cmd == "trgt" ) {
            target = (key)llList2String( parsed, 1 );
            llSetObjectDesc( (string)target );
            if ( target == NULL_KEY ) {
                state default;
            } else {
                // Get Act! status, if present
                integer channel = key2channel( target );
                llListenRemove( actHandle );
                actHandle = llListen( channel, "", NULL_KEY, "" );
                status = "";
                if ( channel ) {
                    llSetLinkPrimitiveParamsFast( moralePrim, 
                        [ PRIM_TEXT, "", ZERO_VECTOR, 0.0 ] );
                    llSetLinkPrimitiveParamsFast( focusPrim, 
                        [ PRIM_TEXT, "", ZERO_VECTOR, 0.0 ] );
                    llRegionSay( channel, (string)target + ":a!png" );
                    rlv = "";
                    if ( llGetAgentSize( target ) ) {
                        llSensorRepeat( "", target, AGENT, 20.0, PI, 5.0 );
                    }
                } else {
                    target = NULL_KEY;
                    state default;
                }
            }
        } else if ( cmd == "rset" ) {
            llResetScript();
        }
    }
    
    timer()
    {
        string name = llKey2Name( target );
        if ( name == "" ) {
            target = NULL_KEY;
            state default;
        }
        
        float now = llGetTime();
        if ( now - last_bearing_change > LONG_TIME  && 
            now - last_facing_change > LONG_TIME ) {
            if ( ! ( llGetAgentInfo( owner ) & AGENT_MOUSELOOK ) ) {
                llSetTimerEvent( VERY_SHORT_TIME );
            }
        }
        check_bearing( target );
        check_facing();
        if ( change_bearing ) {
            rotation rot = llEuler2Rot( <0., 0., last_bearing + PI> ) * hudRot;
            float range = last_range;
            if ( range < 2. ) range = 2.;
            else if ( range > 20. ) range = 20.;
            float cut = .025 + ( ( 0.95/6.0 ) / range );
            llSetLinkPrimitiveParamsFast( LINK_THIS,
                [ PRIM_TYPE, PRIM_TYPE_CYLINDER,
                    PRIM_HOLE_DEFAULT,
                    < 0.75 - cut, 0.75 + cut, 0. >,
                    0.85, <0., 0., 0.>, <1., 1., 0.>, <0., 0., 0.>,
                    PRIM_COLOR, ALL_SIDES, color, 1.0,
                    PRIM_ROTATION, rot ] );
            change_bearing = FALSE;
        }
        if ( change_facing ) {
            llSetLinkPrimitiveParamsFast( compassPrim, [ PRIM_ROT_LOCAL,
                llEuler2Rot( <0., 0., -last_facing> ) * compassRot ] );
            change_facing = FALSE;
        }
        
        vector agent = llGetAgentSize(target);
        if ( agent ) {
            name = llGetDisplayName( target );
            if ( name == "???" ) name = llKey2Name( target );
        }
        if ( llStringLength( name ) > 22 ) {
            name = llGetSubString( name, 0, 20 ) + "…";
        }
        
        if ( status )
        {
            name += " " + status;
        }
        
        vector here = llList2Vector( llGetObjectDetails( llGetOwner(),
            [OBJECT_POS] ), 0 );
        vector there = llList2Vector( llGetObjectDetails( target,
            [OBJECT_POS] ), 0 );
        float hrange = llVecDist( here, there );
        float vsep = there.z - here.z;
        name += " [" + (string)llRound(hrange) + "m ";
        name += compass( there, here );
        if ( vsep < 0.0 ) {
            name += "↓]";
        } else {
            name += "↑]";
        }
        
        if ( agent ) // An agent
        {
            integer info = llGetAgentInfo( target );
            if ( info & AGENT_AWAY ) {
                name += "…";
            } else if ( info & AGENT_BUSY ) {
                name += "✘";
            }
            if ( info & AGENT_FLYING ) {
                name += "▲";
            } else if ( info & AGENT_IN_AIR ) {
                name += "△";
            } else if ( info & AGENT_SITTING ) {
                name += "⚓";
                key target_seat = llList2Key( 
                    llGetObjectDetails( target, [ OBJECT_ROOT ] ), 0 );
                key my_seat = llList2Key( 
                    llGetObjectDetails( llGetOwner(), [ OBJECT_ROOT ] ), 0 );
                if ( my_seat == target_seat ) {
                    name += "h";
                }
            }
            if ( info & AGENT_AUTOMATED ) {
                name += "⬣";
            }
            if ( info & AGENT_MOUSELOOK ) {
                name += "⚔";
            }
        }
        set_text( name + rlv);
    }
}

// This work is licensed under the Creative Commons 
// Attribution-Noncommercial-Share Alike 3.0 United States License. 
// To view a copy of this license, visit 
// http://creativecommons.org/licenses/by-nc-sa/3.0/us/ 
// or send a letter to Creative Commons, 171 Second Street, Suite 300, San 
// Francisco, California, 94105, USA.