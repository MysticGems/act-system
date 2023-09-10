// =========================================================================
// Power Levels                                                            \
// By Jack Abraham                                                      \__
// =========================================================================

float overpower = 0.0;                      // Power in excess of 100%

list powerPrims;
float powerLevel;

integer COMM_MASK           = 0x10000000;   // Communication channel
integer OBJ_MASK            = 0x2000000;    // Construct system channel

integer POWER_MASK          = 0xFFFFF;      // Link message mask for drain
integer POWER_FACE          = 1;            // Prim face for power storage

string LINK_DELIM = "§";
string CHAT_DELIM = "|";

float chargeRatio = 1.0;

integer CHARGE = 1;
integer DAILY = 2;
integer INTERNAL = 3;

float STANDARD_TENTH_PERCENT_DRAIN_TIME = 86.4; // seconds
float DAILY_DRAIN_PER_MINUTE = 0.004166666666666666667;
float INTRINSIC_CHARGE_PER_SECOND = 0.0033333333333333333;

key RECHARGED_SND = "1c2a530b-9aa8-58d1-44a9-71883e0e951d";
key DEAD_SND = "8c45ca98-dc46-d03a-6eee-85e018bce567";

report()
{
    float powerLevel = ((float)llLinksetDataRead( "power" ) * 100.0 ) + overpower;
    string level = llGetSubString( (string)powerLevel, 0, 3 );
    if ( level == "100." ) level = "100";
    llMessageLinked( LINK_ROOT, COMM_MASK,
        llDumpList2String( [ "say", "Power levels " + level + "%" ]
            , LINK_DELIM ),
        llGetOwner() );
}

report_time()
{
    float level =(float)llLinksetDataRead( "power" ) * 4.0 / chargeRatio;
    integer hours = (integer)( level );
    integer minutes = (integer)(level * 60.0 ) % 60;
    llMessageLinked( LINK_ROOT, COMM_MASK,
        llDumpList2String( [ "say", "Charge remaining " + (string)hours
            + " hours, " + (string)minutes + " minutes." ]
            , LINK_DELIM ),
        llGetOwner() );
}

integer userChannel;                    // Channel for HUD-construct comm

integer key2channel( key id )
{
    return -1 * (integer)( "0x" + llGetSubString(id, -10, -3));
}

integer rpPrim;
//  Face 1: Resolve, Drive, Insight
integer RDI = 1;

vector retrieve( integer face )
{
    vector value = llList2Vector( 
            llGetLinkPrimitiveParams( rpPrim, [ PRIM_COLOR, face ] )
        , 0 )
        * 0xFF;
    return value;
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

default // Power ring power mode.  Requires charge, can be depleted.
{
    state_entry()
    {
        userChannel = key2channel( llGetOwner() );
        list prims = get_link_numbers( [ "Act!" ] );
        rpPrim = llList2Integer( prims, 0 );
        //llWhisper( DEBUG_CHANNEL, llGetScriptName() + " initialized; " +
        //    (string)llGetFreeMemory() + " bytes free" );
    }
    
    attach( key id )
    {
        if ( id ) {
            llRequestPermissions( llGetOwner(), llGetPermissions() |
                PERMISSION_TAKE_CONTROLS );
            llSetTimerEvent( STANDARD_TENTH_PERCENT_DRAIN_TIME );
        }
    }
    
    run_time_permissions( integer perm )
    {
        if ( perm & PERMISSION_TAKE_CONTROLS ) {
            llTakeControls( 1024, FALSE, TRUE );
        }
    }    
    
    timer()
    {
        float level =  (float)llLinksetDataRead( "power" );
        if ( level > 0.001 ) {
          llLinksetDataWrite( "power", (string)( level - 0.001 ) );
        }
    }
    
    link_message( integer source, integer chan, string msg, key id )
    {
        if ( chan & OBJ_MASK ) {
            string cmd = llGetSubString( msg, 0, 3 );
            
            // llOwnerSay( "[" + llGetScriptName() + ":" + (string)source + ":" + llKey2Name(id) + ":object]" + msg + " – " + (string)( chan & POWER_MASK ));
            
            if ( msg == "rset" ) {
                llResetScript();
            } else if ( cmd == "fmem" ) {
                llMessageLinked( source, llGetFreeMemory(), "fmem", id );
            } else if ( msg == "drain" ) {
                float drain = (float)( chan & POWER_MASK ) / 5000.0;
                float level = (float)llLinksetDataRead( "power" ) * 100.0;
                if ( overpower > 0 ) {
                    overpower -= drain;
                    if ( overpower < 0.0 ) {
                        drain = -1 * overpower;
                        overpower = 0.0;
                    } else {
                        drain = 0.0;
                    }
                }
                llLinksetDataWrite( "power", (string)(( level - drain )/100.0 ));
                //llOwnerSay( "Drain " + (string)( drain * 100.0 ) + "%; "
                //    + "power levels " 
                //    + (string)( (float)llLinksetDataRead( "power" ) * 100. ) + "%" );
            } else if ( cmd == "chrg" ) {
                list parsed = llParseString2List( msg, [ LINK_DELIM ], [] );
                cmd = llList2String( parsed, 1 );
                if ( cmd == "level" ) {
                    report();
                } else if ( cmd == "energy req" ) {
                    float req = (float)llList2String( parsed, 3 ) / 
                        chargeRatio;
                    float avail = (float)llLinksetDataRead( "power" );
                    if ( req < avail ) {
                        llLinksetDataWrite( "power", (string)(avail - req ) );
                        llSay( userChannel, 
                            llDumpList2String( llList2List( parsed, 2, 2 )
                                + [ "energy" ], CHAT_DELIM ) );
                    }
                } else if ( cmd == "recharge" ) {
                    float level = (float)llLinksetDataRead( "power" ) * 100.0;
                    level += overpower;
                    vector power = llGetColor( POWER_FACE ) * 0xFF;
                    integer band = (integer)llList2String( parsed, 2 );
                    if ( band == ( (integer)power.x & 0x1F ) ) {
                        float charge = (float)llList2String( parsed, 3 );
                        float max = (float)llList2String( parsed, 4 );
                        if ( level <= 0.0 && charge >= 0.0 ) {
                            llWhisper( key2channel( llGetOwner() ), "ignite" );
                            llPlaySound( RECHARGED_SND, 1.0 );
                        }
                        level += charge;
                        if ( level > max ) level = max;
                        if ( level > 100.0 ) {
                            vector rdi = retrieve( RDI );
                            level = llListStatistics( LIST_STAT_MIN, [ level,
                                100.0 + ( 2 * rdi.y ) ] );
                            overpower = level - 100.0;
                            level = 100.0;
                        }
                        llLinksetDataWrite( "power", (string)(level / 100.0) );
                    }
                } else if ( cmd == "source" ) {
                    integer mode = (integer)llList2String( parsed, 2 );
                    chargeRatio = (float)llList2String( parsed, 3 );
                    if ( mode == CHARGE ) {
                        state default;
                    } else if ( mode == DAILY ) {
                        state daily;
                    } else if ( mode == INTERNAL ) {
                        state internal;
                    }
                }
            } else if ( cmd == "fmem" ) {
                llMessageLinked( source, llGetFreeMemory(), "fmem", id );
            } else if ( msg == "diag" ) {
                llWhisper( 0, "/me POWER SYSTEM" +
                    "\n" + (string)llGetFreeMemory() + " bytes free."
                    + "\nRecharge mode"
                    + "\nPower Face: " 
                        + (string)( llGetColor( POWER_FACE ) * 0xFF )
                    + "\nPower Level: " + llLinksetDataRead( "power" )
                    );
            }
        }
    }
    
    changed( integer change )
    {
        if ( change & CHANGED_COLOR ) {
            float level = ( overpower / 100.0 ) + (float)llLinksetDataRead( "power" );
            if ( powerLevel < 1.0 && overpower > 0.0 ) {
                overpower -= 1.0 - powerLevel;
                powerLevel = 1.0;
                llLinksetDataWrite( "power", (string)level );
            } else if ( llFabs( powerLevel - level ) >= 0.05 ) {
                powerLevel = level;
                report();
            }
            if ( level <= 0 ) {
                llWhisper( key2channel( llGetOwner() ), "douse" );
                report();
                llPlaySound( DEAD_SND, 1.0 );
            }
        }
        if ( change & CHANGED_OWNER ) 
        {
            llSetAlpha( 0.0, POWER_FACE );
        }
    }
    
    object_rez( key construct )
    {
        float mass = llGetObjectMass( construct );
        float drain;
        drain = llSqrt( mass ) / ( chargeRatio * 10000.0 );
        if ( drain ) {
            float level = (float)llLinksetDataRead( "power" );
            llLinksetDataWrite( "power", (string)( level - drain ) );
        }
    }
}

state daily // Requires daily charge
{
    state_entry()
    {
        llOwnerSay( "Recharge every " + (string)llRound( 4.0 / chargeRatio ) 
            + " hours." );
        llSetTimerEvent( 60.0 );
    }
    
    attach( key id )
    {
        if ( id ) {
            llRequestPermissions( llGetOwner(), llGetPermissions() |
                PERMISSION_TAKE_CONTROLS );
        }
    }
    
    run_time_permissions( integer perm )
    {
        if ( perm & PERMISSION_TAKE_CONTROLS ) {
            llTakeControls( 1024, FALSE, TRUE );
        }
    }    
    
    link_message( integer source, integer chan, string msg, key id )
    {
        if ( chan & OBJ_MASK ) {
            string cmd = llGetSubString( msg, 0, 3 );
            
            // llOwnerSay( "[" + llGetScriptName() + ":" + (string)source + ":" + llKey2Name(id) + ":object]" + message );
            
            if ( msg == "rset" ) {
                llResetScript();
            } else if ( cmd == "fmem" ) {
                llMessageLinked( source, llGetFreeMemory(), "fmem", id );
            } else if ( cmd == "chrg" ) {
                list parsed = llParseString2List( msg, [ LINK_DELIM ], [] );
                cmd = llList2String( parsed, 1 );
                if ( cmd == "level" ) {
                    report_time();
                } else if ( cmd == "energy req" ) {
                    llSay( userChannel, 
                        llDumpList2String( llList2List( parsed, 2, 2 )
                            + [ "energy" ], CHAT_DELIM ) );
                } else if ( cmd == "recharge" ) {
                    float level = (float)llLinksetDataRead( "power" );
                    vector power = llGetColor( POWER_FACE ) * 0xFF;
                    integer band = (integer)llList2String( parsed, 2 );
                    if ( band == ((integer)power.x & 0x1F )) {
                        float charge = (float)llList2String( parsed, 3 );
                        float max = (float)llList2String( parsed, 4 );
                        level += overpower;
                        if ( level <= 0.0 && charge >= 0.0 ) {
                            llWhisper( key2channel( llGetOwner() ), "ignite" );
                            llPlaySound( RECHARGED_SND, 1.0 );
                        }
                        level += charge;
                        if ( level > max ) level = max;
                        if ( level > 100 ) {
                            overpower = level - 100;
                            level = 100;
                        }
                        llLinksetDataWrite( "power", (string)( level / 100.0 ) );
                    }
                    llSetTimerEvent( 60.0 );
                } else if ( cmd == "source" ) {
                    integer mode = (integer)llList2String( parsed, 2 );
                    chargeRatio = (float)llList2String( parsed, 3 );
                    if ( mode == CHARGE ) {
                        state default;
                    } else if ( mode == DAILY ) {
                        state daily;
                    } else if ( mode == INTERNAL ) {
                        state internal;
                    }
                }
            } else if ( cmd == "fmem" ) {
                llMessageLinked( source, llGetFreeMemory(), "fmem", id );
            } else if ( msg == "diag" ) {
                llWhisper( 0, "/me POWER SYSTEM" +
                    "\n" + (string)llGetFreeMemory() + " bytes free."
                    + "\nDaily mode"
                    + "\nPower Face: " 
                        + (string)( llGetColor( POWER_FACE ) * 0xFF )
                    + "\nPower Level: " + llLinksetDataRead( "power" )
                    );
            }
        }
    }
    
    changed( integer change )
    {
        if ( change & CHANGED_COLOR )
        {
            float currentCharge = (float)llLinksetDataRead( "power" );
            if ( currentCharge < 0.0 ) {
                report_time();
                llSetTimerEvent( 0. );
            } 
            else if ( currentCharge < 0.021 )
            {
                report_time();
            }
            if ( currentCharge <= 0.0 ) {
                llWhisper( key2channel( llGetOwner() ), "douse" );
                report_time();
                llPlaySound( DEAD_SND, 1.0 );
                llSetTimerEvent( 0.0 );
            }
        }
        if ( change & CHANGED_OWNER ) 
        {
            llLinksetDataWrite( "power", (string)0.0 );
        }
    }
    
    timer()
    {
        float level = (float)llLinksetDataRead( "power" ) - 
            (DAILY_DRAIN_PER_MINUTE * chargeRatio);
        llLinksetDataWrite( "power", (string)level );
    }
}

state internal // Power can be drained, but recharges fully in 10 minutes
{
    state_entry()
    {
        llOwnerSay( "Running on internal power." );
        if ( (float)llLinksetDataRead( "power" ) < 1.0 ) {
            llSetTimerEvent( 1.0 );
        }
    }
    
    attach( key id )
    {
        if ( id ) {
            llRequestPermissions( llGetOwner(), llGetPermissions() |
                PERMISSION_TAKE_CONTROLS );
        }
    }
    
    run_time_permissions( integer perm )
    {
        if ( perm & PERMISSION_TAKE_CONTROLS ) {
            llTakeControls( 1024, FALSE, TRUE );
        }
    }    
    
    link_message( integer source, integer chan, string msg, key id )
    {
        if ( chan & OBJ_MASK ) {
            string cmd = llGetSubString( msg, 0, 3 );
            
            // llOwnerSay( "[" + llGetScriptName() + ":" + (string)source + ":" + llKey2Name(id) + ":object]" + msg );
            
            if ( msg == "rset" ) {
                llResetScript();
            } else if ( cmd == "fmem" ) {
                llMessageLinked( source, llGetFreeMemory(), "fmem", id );
            } else if ( msg == "drain" ) {
                float drain = (float)( chan & POWER_MASK ) / 1250.0;
                float level = (float)llLinksetDataRead( "power" ) * 100.0;
                if ( overpower > 0 ) {
                    overpower -= drain;
                    if ( overpower < 0.0 ) {
                        drain = -1 * overpower;
                        overpower = 0.0;
                    } else {
                        drain = 0.0;
                    }
                }
                llLinksetDataWrite( "power", (string)( ( level - drain ) / 100.0 ) );
            } else if ( cmd == "chrg" ) {
                list parsed = llParseString2List( msg, [ LINK_DELIM ], [] );
                cmd = llList2String( parsed, 1 );
                if ( cmd == "level" ) {
                    report();
                } else if ( cmd == "energy req" ) {
                    float req = (float)llList2String( parsed, 3 ) / 
                        chargeRatio;
                    float avail = (float)llLinksetDataRead( "power" );
                    if ( req < avail ) {
                        llLinksetDataWrite( "power", (string)( avail - req) );
                        llSay( userChannel, 
                            llDumpList2String( llList2List( parsed, 2, 2 )
                                + [ "energy" ], CHAT_DELIM ) );
                    }
                } else if ( cmd == "recharge" ) {
                    float level = (float)llLinksetDataRead( "power" ) * 100.0;
                    level += overpower;
                    vector power = llGetColor( POWER_FACE ) * 0xFF;
                    integer band = (integer)llList2String( parsed, 2 );
                    if ( band == ((integer)power.x & 0x1F )) {
                        float charge = (float)llList2String( parsed, 3 );
                        float max = (float)llList2String( parsed, 4 );
                        if ( level <= 0.0 && charge >= 0.0 ) {
                            llWhisper( key2channel( llGetOwner() ), "ignite" );
                            llPlaySound( RECHARGED_SND, 1.0 );
                        }
                        level += charge;
                        if ( level > max ) level = max;
                        if ( level > 100.0 ) {
                            overpower = level - 100.0;
                            level = 100.0;
                        }
                        llLinksetDataWrite( "power", (string)( level / 100.0 ) );
                    }
                } else if ( cmd == "source" ) {
                    integer mode = (integer)llList2String( parsed, 2 );
                    chargeRatio = (float)llList2String( parsed, 3 );
                    if ( mode == CHARGE ) {
                        state default;
                    } else if ( mode == DAILY ) {
                        state daily;
                    } else if ( mode == INTERNAL ) {
                        state internal;
                    }
                }
            } else if ( cmd == "fmem" ) {
                llMessageLinked( source, llGetFreeMemory(), "fmem", id );
            } else if ( msg == "diag" ) {
                llWhisper( 0, "/me POWER SYSTEM" +
                    "\n" + (string)llGetFreeMemory() + " bytes free."
                    + "\nRecharge mode"
                    + "\nPower Face: " 
                        + (string)( llGetColor( POWER_FACE ) * 0xFF )
                    + "\nPower Level: " + llLinksetDataRead( "power" )
                    );
            }
        }
    }
    
    changed( integer change )
    {
        if ( change & CHANGED_COLOR ) {
            float level = (float)llLinksetDataRead( "power" );
            if ( powerLevel < 1.0 && overpower > 0.0 ) {
                overpower -= 1.0 - powerLevel;
                powerLevel = 1.0;
                llLinksetDataWrite( "power", (string)(1.0) );
                return;
            } else if ( llFabs( powerLevel - level ) > 0.05 ) {
                powerLevel = llGetAlpha( 1 );
                report();
            }
            if ( level < 1.0 ) {
                llSetTimerEvent( 1.0 );
            } else {
                llSetTimerEvent( 0.0 );
            }
            if ( level <= 0.0 ) {
                llWhisper( key2channel( llGetOwner() ), "douse" );
                report();
                llPlaySound( DEAD_SND, 1.0 );
            }
        }
        if ( change & CHANGED_OWNER ) 
        {
            llLinksetDataWrite( "power", (string)0.0 );
        }
    }
    
    timer()
    {
        float level = (float)llLinksetDataRead( "power" );
        level += INTRINSIC_CHARGE_PER_SECOND;
        if ( level > 1.0 ) level = 1.0;
        llLinksetDataWrite( "power", (string)level );
    }
    
    object_rez( key construct )
    {
        float mass = llGetObjectMass( construct );
        float drain;
        drain = llSqrt( mass ) / ( 2500.0 * chargeRatio );
        if ( drain ) {
            float powerLevel = (float)llLinksetDataRead( "power" );
            llLinksetDataWrite( "power", (string)( powerLevel - drain ) );
        }
    }
}


// Copyright ©2023 Jack Abraham and player, all rights reserved
// Contact Guardian Karu in Second Life for distribution rights