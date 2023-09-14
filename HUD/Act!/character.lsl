// ===========================================================================
// Character Sheet                                                           \
// By Jack Abraham                                                        \__ 
// ===========================================================================

string charName = "";                                       // Who am I?
string charKey = "4513d163-9eed-360a-7e8d-413d6a70be07";    // Character key

string defaultCharacter = "Act! Character";
integer DEFAULT_LEVEL = 64;
key defaultLicense = "4513d163-9eed-360a-7e8d-413d6a70be07";

string BLANK_CHARACTER = "( Unused )";
string RESOURCE_SCRIPT = "resources.lsl";

float charLevel = 64.0;                 // Attribute scale, max 128
float trait_cost = 0.025;               // Cost of a Trait
float skill_cost = 0.025;               // Cost of Skill +1.0

// Values stored in faces:
//  Face 0: Nutrition, Arousal, 
integer NEEDS = 0;
//  Face 1: Resilience, Drive, Insight
//  Also stored in color of PRIM_POINT_LIGHT for easy reset after buff/debuff
integer RDI = 1;
//  Face 2: Injury status conditions, Endurance, Focus
integer SMF = 2;
//  Face 3: Resistance Bonus, Damage Resistance, Combat status conditions
integer DEFENSES = 3;
//  Face 4: Displayed face toward user; do not use
//  Face 5: Power recovery rate, Max Power, Resolve recovery rate
integer RECOVERY = 5;
// Face 6: Damage modifier, DB modifier, Attack flags
// License key in texture field
integer COMBAT = 6;

vector attributes;
list traits = [];
list skills = [];

integer BROADCAST_MASK      = 0xFFF00000;
integer RP_MASK             = 0x4000000;
// integer OBJ_MASK            = 0x2000000;

integer detached;                   // Time taken off

// =========================================================================
// Task roll
// =========================================================================

string FAIL = "FAIL";
string SUCCESS = "SUCCESS";

// Action format:
//       Key of object to reply to (owner for internal calls)
//       |            Signal to send with success/failure
//       |            |   Attribute rolled against
//       |            |   |         Skill to modify attribute*
//       |            |   |         |     Trait required to attempt*
//       |            |   |         |     |    Modifier to probability*
//       |            |   |         |     |     |
// a!act:reply-to-key:000:attribute:skill:trait:0.00
//
// * Optional field, but delimiters for prior fields required

action( integer sender, string msg )
{
    list params = llParseStringKeepNulls( msg, 
        [ LINK_DELIM, ACT_DELIM ], [] );
    params = llDeleteSubList( params, 0, 1 );
    string trait = "";
    string skill = "";
    float mod = 0.0;
    float numberOfParams = llGetListLength( params );
    if ( numberOfParams > 3 ) {
        skill = llList2String( params, 3 );
    }
    if ( numberOfParams > 4 ) {
        trait = llList2String( params, 4 );
    }
    if ( numberOfParams > 5 ) {
        mod = (float)llList2String( params, 5 );
    }
    
    if ( llList2String( params, 0 ) == (string)llGetOwner() ) {
        llMessageLinked( sender, (integer)llList2String( params, 1 ), 
            llDumpList2String( 
                [ action_roll( llList2String( params, 2 ), skill, trait, mod ) ], 
                LINK_DELIM ), llGetOwner() );
    } else {
        send( key2channel( (key)llList2String( params, 0 ) ), 
            (integer)llList2String( params, 1), 
            [ action_roll( llList2String( params, 2 ), skill, trait, mod ) ] );
    }
}

// Trait check:
//       Key of object to reply to (owner for internal calls)
//       |            Signal to send with success or failure
//       |            |   Trait to check
//       |            |   |
// a!trt:reply-to-key:000:trait

trait( integer sender, string trait )
{
    list params = llParseStringKeepNulls( trait, [ ACT_DELIM ], [] );
    params = llDeleteSubList( params, 0, 0 );
    string result = FAIL;
    if ( have_trait( llList2String( params, 2 ) ) ) {
        result = SUCCESS;
    }
    if ( llList2String( params, 0 ) == (string)llGetOwner() ) {
        llMessageLinked( sender, (integer)llList2String( params, 1), 
            llDumpList2String( [ result ], LINK_DELIM ), llGetOwner() );
    } else {
        send( key2channel( (key)llList2String( params, 0 ) ), 
            (integer)llList2String( params, 1), 
            [ result ] );
    }
}

string action_roll( string attribute, string skill, string trait, float modifier )
{
    // Sends SIG for success; nothing for failure.
    attribute = llToLower( attribute );
    trait = llToLower( trait );
    skill = llToLower( skill );
    vector allAttributes = retrieve( RDI );
    integer attrib;
    if ( attribute == "resilience" ) attrib = (integer)allAttributes.x;
    else if ( attribute == "drive" ) attrib = (integer)allAttributes.y;
    else if ( attribute == "insight" ) attrib = (integer)allAttributes.z;
    else return FAIL;

    // Trait is required; fail if you don't have it.
        
    if ( trait ) {
        string mod = llGetSubString( trait, 0 , 0 );
        if ( mod == "!" ) {
            if ( have_trait( llGetSubString( trait, 1, -1 ) ) ) {
                // Attempt roll only if you do not have the trait
                return SUCCESS;
            }
        }
        if ( !have_trait( trait ) ) {
            return FAIL;
        }
    }

    if ( skill ) {
        integer i = llListFindList( skills, [ skill ] );
        if ( i > -1 ) {
            modifier += llList2Float( skills, i + 1 );
        }
    }
    
    integer roll = (integer)llFrand( 65.0 );
    // llOwnerSay( "Success chance: " 
    //     + (string)llRound( (float)attrib * ( 1.0 + modifier ) ) );
    // llOwnerSay( "Rolled " + (string)roll );
    if ( roll < llRound( (float)attrib * ( 1.0 + modifier ) ) ) {
        return SUCCESS;
    }
    return FAIL;
}

integer have_trait( string trait ) 
{
    list check = llParseString2List( trait, ["|"], [] );
    integer c = llGetListLength( check );
    integer i;
    for ( i=0; i<c; i++ ) {
        if ( llListFindList( traits, [ llList2String(check, i) ] ) > -1 ) {
            return TRUE;
        }
    }
    return FALSE;
}

store_all_values()
{
    attributes = llVecNorm( attributes ) * charLevel;
    attributes *= 1.0 - 
        ( trait_cost * (float)llGetListLength( traits )) -
        ( skill_cost * (float)( llListStatistics( LIST_STAT_SUM, skills ) ));
    attributes = <llRound( attributes.x ),
        llRound( attributes.y ),
        llRound( attributes.z )>;
    store( attributes, RDI );
    llSetLinkPrimitiveParamsFast( LINK_THIS, [ PRIM_POINT_LIGHT, TRUE,
        attributes / 0xFF, charLevel / 0xFF, 0.01, 1.0 ] );
    store( ZERO_VECTOR, SMF );
    store( <attributes.x / 25.0,
        ( attributes.y + attributes.z ),
        attributes.x / 50.0>, RECOVERY );
    store( <0.0, 0.0, 0.0>, DEFENSES );
    llSetObjectDesc( charName );
    llSetText( llList2CSV( traits ), ZERO_VECTOR, 0.0 );
}

// =========================================================================
// Output functions
// =========================================================================

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

send( integer dest, integer sig, list message ) {
    llSay( dest, llDumpList2String( [ sig ] + message, ACT_DELIM ) );
}

integer menuPrim = LINK_SET;            // Where's the menu?

integer key2channel( key who ) {
    return -1 * (integer)( "0x" + llGetSubString( (string)who, -12, -5 ) );
}

sheet_to_chat()
{
    string output = "/me - " + charName + " - Level " 
        + (string)llRound(charLevel ) 
        + "\n";
    vector rdi = retrieve( RDI );
    vector smf = retrieve( SMF );
    vector def = retrieve( DEFENSES );
    vector rec = retrieve ( RECOVERY );
    output += "[Resilience: " + (string)llRound( rdi.x / 0.64 )
        + "%] [Drive: " + (string)llRound( rdi.y / 0.64 )
        + "%] [Insight: " + (string)llRound( rdi.z / 0.64 ) + "%]";
    output += "\n[Endurance: " + (string)llRound( smf.y )
        + "/" + (string)llRound( rdi.y + rdi.x )
        + "] [Focus: " + (string)llRound(smf.z ) + "/"
        + (string)llRound( rdi.y + rdi.z ) + "]"
        + " [Resistance Bonus: " + (string)( llRound(def.x) ) + "]";
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
    announce( output, FALSE );
}

announce( string text, integer public )
{
    string primName = llGetObjectName();
    llSetObjectName( llGetDisplayName( llGetOwner() ) );
    if ( public ) {
        llSay( 0, text );
    } else {
        llOwnerSay( text );
    }
    llSetObjectName( primName );
}

// ===========================================================================
// Update prim level bars

integer endPrim;
integer focusPrim;
integer statesPrim;
integer arousalPrim;
integer hungerPrim;

string SOLID =   "▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮";
string HOLLOW =  "▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯";
string DAMAGED = "____________________";
integer MAX_TICKS = 15;
vector ENDURANCE_COLOR = <0.3333, 1.0, 0.3333>;
vector AROUSAL_COLOR = <1.0, 0.5, 0.5>;
vector FOCUS_COLOR = <0.0, 0.6667, 1.0>;

string HUDmode;

list showFocusModes =                   // Show focus bar in these modes
    [ "combat", "construct", "Act!" ];
integer showFocus = TRUE;               // Show the focus bar or not

set_bar_level( float current, float attrib, float max, integer prim, vector color, 
    integer line )
{
    string bar;
    float ratio;
    float maximum;
    attrib = (float)llFloor( attrib );
    max = (float)llFloor( max );
    
    if ( current < 0 ) current = 0.0;
    if ( attrib > 0 ) {
        ratio = ( current / attrib );
        maximum = ( max / attrib );
    }
    integer level = (integer)( ratio * (float)MAX_TICKS );
    integer limit = (integer)( maximum * (float)MAX_TICKS );
    if ( level ) {
        bar = llGetSubString( SOLID, 0, level - 1 );
    }
    if ( level < limit ) {
        bar += llGetSubString( HOLLOW, 0, limit - level - 1 );
    }
    if ( limit < MAX_TICKS ) {
        bar += llGetSubString( DAMAGED, 0, MAX_TICKS - limit - 1 );
    }
    llSetLinkPrimitiveParamsFast( prim, [ PRIM_TEXT, bar, color, 1.0 ] );
    // llSay( 0, llDumpList2String( [ current, attrib, max, level, limit ], "/" ) );
}

// Bitmasks for states (resources.x)
integer STUNNED_MASK = 0x2;         // ?
integer RESTRAINED_MASK = 0x4;      // ?
integer DEFEATED_MASK = 0x8;        // ?
integer WOUNDED_MASK = 0x10;        // ?
integer VULNERABLE_MASK = 0x80;     //
integer TURN_MASK = 0x100;          // Using turn-based time
integer SEX_MASK = 0x200;           // Using Sex Act!

// Bitmasks for combat status (defenses.z)
integer COMBAT_MASK = 0x01;         //
integer INVULNERABLE_MASK = 0x02;   //
integer DEFENDING_MASK = 0x04;      //
integer PEACE_MASK = 0x08;          //

update_display()
{
    vector srp = retrieve( SMF );
    vector rdi = retrieve( RDI );
    vector rec = retrieve( RECOVERY );
    vector defenses = retrieve( DEFENSES );
    vector needs = retrieve( NEEDS );
    
    if ( (integer)defenses.z & SEX_MASK ) {
        set_bar_level( srp.y, rdi.y + rdi.x, rdi.y + rdi.x,
            endPrim, AROUSAL_COLOR, 1 ); 
    } else {
        set_bar_level( srp.y, rdi.y + rdi.x, rdi.y + rdi.x,
            endPrim, ENDURANCE_COLOR, 1 ); 
    }
    set_bar_level( srp.z, rdi.y + rdi.z, rec.y,
        focusPrim, FOCUS_COLOR, 0 );
    integer states = (integer)srp.x;
    list status;
    if ( (integer)defenses.z & TURN_MASK ) {
        status += "↺";
    }
    if ( states & STUNNED_MASK ) {
        status += "⊘";
    }
    if ( states & WOUNDED_MASK ) {
        status += "☤";
    }
    if ( states & RESTRAINED_MASK ) {
        status += "◉";
    }
    if ( states & VULNERABLE_MASK ) {
        status += "‼";
    }
    if ( (integer)defenses.z & COMBAT_MASK ) {
        if ( (integer)defenses.z & SEX_MASK ) {
            status += "⚤";
        } else {
            status += "⚔";
        }
    }
    if ( (integer)defenses.z & INVULNERABLE_MASK ) {
        status += "Inv";
    }
    if ( (integer)rec.y < (integer)rdi.y + (integer)rdi.z ) {
        status += "_";
    }
    if ( states & DEFEATED_MASK ) {
        status = ["◤◢◤◢ Defeated ◤◢◤◢"];
    }
    llSetLinkPrimitiveParams( statesPrim, 
        [ PRIM_TEXT, llDumpList2String( status, " " ),
            <1.0, 1.0, 1.0>, 1.0 ] );
}

// ------------------------------------------------------------------------
// Experience keys access

key charID = NULL_KEY;                  // Character sheet not yet requested
key constID = NULL_KEY;                 // Get constants from the experience
string DATA_DELIM = "§";

key put_data(string id, string value, string original)
{
    llSleep( 1.0 );
    integer verify = FALSE;
    if ( original ) {
        integer verify = TRUE;
    }
    return llUpdateKeyValue( id, value, verify, original );
}

// ===========================================================================
// Functions to store/retrieve attribute values

store( vector store, integer face )
{
    store /= 0xFF;
    if ( llGetColor( face ) != store ) {
        llSetColor( store, face );
    }
}

vector retrieve( integer face )
{
    return llGetColor( face ) * 0xFF;
}

// ===========================================================================

default // Setup
{
    state_entry()
    {
        llSetText( "", ZERO_VECTOR, 0.0 );
        list prims = get_link_numbers_for_names(
            [ "menu", "states", "endurance", "focus" ] );
        menuPrim = llList2Integer( prims, 0 );
        statesPrim = llList2Integer( prims, 1 );
        endPrim = llList2Integer( prims, 2 );
        focusPrim = llList2Integer( prims, 3 );
        llSetLinkPrimitiveParams( statesPrim, 
            [ PRIM_TEXT, "", <1.0, 0.625, 0.625>, 1.0 ] );
        if ( llGetNumberOfSides() < COMBAT + 1 ) {
            llSay( DEBUG_CHANNEL, 
                "Insufficient prim faces for data storage; need " 
                + (string)COMBAT + ".");
            state error;
        }
        //llOwnerSay( llGetScriptName() + " starting; " + (string)llGetFreeMemory()
        //    + " bytes free." );
        if ( llGetAttached()  ) {
            if ( llAgentInExperience( llGetOwner() ) ) {
                if ( charKey == NULL_KEY ) {
                    if ( defaultLicense != NULL_KEY ) {
                        charName = defaultCharacter;
                        charKey = (string)defaultLicense + "-Act!";
                        charLevel = DEFAULT_LEVEL;
                        charID = llReadKeyValue( charKey );
                    } else {
                        // Start polling for default license
                        llSetTimerEvent( 5.0 );
                    }
                } else {
                    charKey = (string)llGetOwner() + "-Act!";
                    llOwnerSay( "Retrieving character sheet." );
                    charID = llReadKeyValue( charKey );
                }
            } else {
                llOwnerSay( "Your experience is not active here. Please reattach your HUD when you are in an area that allows the experience." );
                llRequestPermissions( llGetOwner(), PERMISSION_ATTACH );
            }
        }
    }
            
    run_time_permissions( integer perm ) {
        if ( perm & PERMISSION_ATTACH ) {
            if ( llGetAttached() ) {
                llDetachFromAvatar();
            }
        }
    }

    timer()
    {
        if ( defaultLicense == NULL_KEY ) {
            llWhisper( key2channel( llGetOwner() ), llDumpList2String(
                [ llGetOwner(), "a?int" ], ACT_DELIM ) );
        } else {
            llSetTimerEvent( 0. );
        }
    }
    
    dataserver( key id, string body )
    {
        if ( !( id == charID || id == constID ) ) return;
        
        body = llStringTrim( body, STRING_TRIM );
        
        if (llGetSubString(body,0,0) == "1") {
            body = llGetSubString( body, 2, -1 );
            if ( id == charID ) {
            // Read from the data server
                list data = llParseString2List( body, [ DATA_DELIM ], [] );
                
                integer i = llListFindList( data, ["background"] );
                if ( i > -1 ) {
                    list background = llParseString2List( 
                        llList2String( data, i+1 ),
                        [ "^" ], [] );
                    i = llListFindList( background, ["name"] );
                    if ( i > -1 ) {
                        charName = llList2String( background, i + 1 );
                    } else {
                        charName = llGetDisplayName( llGetOwner() );
                    }
                }

                i = llListFindList( data, ["level"] );
                if ( i > -1 ) {
                    charLevel = (integer)llList2String( data, i + 1 );
                }

                i = llListFindList( data, ["attributes"] );
                if ( i > -1 ) {
                    attributes = (vector)llList2String( data, i + 1 );
                }
                
                i = llListFindList( data, ["traits"] );
                if ( i > -1 && llList2String( data, i+1 ) != "NO_DATA" ) {
                    traits = llParseString2List( llList2String( data, i+1 ),
                        [ "^" ], [] );
                } else {
                    traits = [];
                }
                
                i = llListFindList( data, ["skills"] );
                if ( i > -1 && llList2String( data, i+1 ) != "NO_DATA" ) {
                    skills = llParseString2List( llList2String( data, i+1 ),
                        [ "^" ], [] );
                    integer c = 1;
                    integer l = llGetListLength( skills );
                    float val;
                    while ( c < l ) {
                        val = (float)llList2String( skills, c );
                        if ( val != 0.0 ) {
                            skills = llListReplaceList( skills, [val], c, c );
                        }
                        c += 2;
                    }
                } else {
                    skills = [];
                }
                constID = llReadKeyValue( "character-constants" );
            } else if ( id == constID ) {
                list values = llCSV2List( body );
                trait_cost = llList2Float( values, 0 );
                skill_cost = llList2Float( values, 1 );
                store_all_values();
                state active;
            }
        } else {
            // Failed to read
            list error_num = llCSV2List( body );
            integer error = llList2Integer( error_num, 1 );
            llOwnerSay("Error retrieving character sheet; Act! is disabled.\nError: " + llGetExperienceErrorMessage( error ) );
        }
    }
    
    link_message( integer sender, integer signal, string msg, key id )
    {
        if ( signal & RP_MASK ) {
            
            string cmd = llGetSubString( msg, 0, 3 );
    
            if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "act!" ) {
                list parsed = llParseString2List( msg, 
                    [ LINK_DELIM, ACT_DELIM ], [] );
                cmd = llList2String( parsed, 1 );
                if ( cmd == "char" ) {
                    charName = llList2String( parsed, 2 );
                    if ( charName == "default" ) {
                        charName = defaultCharacter;
                        charKey = defaultLicense;
                        charLevel = DEFAULT_LEVEL;
                    } else {
                        charKey = (key)llList2String( parsed, 3 );
                        charLevel = (float)llList2String( parsed, 4 );
                    }
                    charID = llReadKeyValue( charKey );
                } else if ( cmd == "a!int" ) {
                    if ( defaultLicense == NULL_KEY && 
                        llGetOwnerKey( id ) == llGetOwner() ) 
                    {
                        defaultCharacter = llList2String( parsed, 2 );
                        defaultLicense = (key)llList2String( parsed, 3 );
                        if ( charKey == NULL_KEY ) {
                            charName = defaultCharacter;
                            charKey = defaultLicense;
                            charLevel = DEFAULT_LEVEL;
                            charID = llReadKeyValue( charKey );
                        }
                    }
                    llSetTimerEvent( 0. );
                } else {
                    llResetScript();
                }
            }
        }
    }
}

state error
{
    state_entry()
    {
        llOwnerSay( "/me encountered a problem reading your character sheet." );
    }
    
    on_rez( integer p )
    {
        llResetScript();
    }
    
    changed( integer change )
    {
        llResetScript();
    }
    
    link_message( integer sender, integer signal, string msg, key id )
    {
        if ( signal & RP_MASK ) {
            string cmd = llGetSubString( msg, 0, 3 );
            
            if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "act!" ) {
                llResetScript();
            } else if ( cmd == "xxxx" ) {
                if ( id == llGetLinkKey( 2 ) ) {
                    integer c = llGetInventoryNumber( INVENTORY_ALL );
                    string name;
                    string this = llGetScriptName();
                    while ( c-- ) {
                        name = llGetInventoryName( INVENTORY_ALL, c );
                        if ( name != this ) {
                            llRemoveInventory( name );
                        }
                    }
                    llRemoveInventory( llGetScriptName() );
                }
            }
        }
    }
}

// ===========================================================================

state active
{
    state_entry()
    {
        llOwnerSay( "Character sheet active; " 
            + (string)llGetFreeMemory()
            + " bytes free." );
        sheet_to_chat();
        if ( llGetInventoryType( RESOURCE_SCRIPT ) == INVENTORY_SCRIPT ) {
            llResetOtherScript( RESOURCE_SCRIPT );
        }
        llMessageLinked( LINK_ALL_OTHERS, BROADCAST_MASK, "char", charKey );
    }

    link_message( integer sender, integer signal, string msg, key id )
    {
        if ( signal & RP_MASK ) {
            string cmd = llToLower( llGetSubString( msg, 0, 3 ) );
            
            if ( cmd == "act!" ) {
                list parsed = llParseStringKeepNulls( msg, 
                    [ LINK_DELIM, ACT_DELIM ], [] );
                cmd = llList2String( parsed, 1 );
                
                // llOwnerSay( "\"" + cmd + "\"" );
                
                if ( cmd == "char" ) {
                    llSetObjectDesc( defaultCharacter );
                    charKey = llGetKey();
                    llSay( 0, "Character sheet reload by " +
                        llGetDisplayName(llGetOwner()) + "." ); 
                    state default;
                } else if ( cmd == "stat" ) {
                    sheet_to_chat();
                } else if ( cmd == "a!act" ) {
                    action( sender, msg );
                } else if ( cmd == "a!trt" ) {
                    trait( sender, llGetSubString( msg, 5, -1 ) );
                }
            } else if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "diag" ) {
                llWhisper( 0, "/me CHARACTER SHEET\n" +
                    (string)llGetFreeMemory() + " bytes free" +
                    "\nName: " + charName +
                    "\nKey: " + (string)charKey +
                    "\nRDI: " + (string)retrieve(RDI) + 
                    "\nSMF:" + (string)retrieve(SMF) +
                    "\nDefenses: " + (string)retrieve(DEFENSES) +
                    "\nRecovery: " + (string)retrieve(RECOVERY) +
                    "\nCombat Buffs: " + (string)retrieve(COMBAT));
            } else if ( cmd == "fmem" ) {
                llMessageLinked( sender, llGetFreeMemory(), "fmem", id );
            } else if ( cmd == "xxxx" ) {
                if ( id == llGetLinkKey( 2 ) ) {
                    integer c = llGetInventoryNumber( INVENTORY_ALL );
                    string name;
                    string this = llGetScriptName();
                    while ( c-- ) {
                        name = llGetInventoryName( INVENTORY_ALL, c );
                        if ( name != this ) {
                            llRemoveInventory( name );
                        }
                    }
                    llRemoveInventory( llGetScriptName() );
                }
            }
        }
    }
    
    attach( key id )
    {
        if ( id ) {
            if ( llAgentInExperience( llGetOwner() ) ) {
                llSleep( 5.0 );
                store( ZERO_VECTOR, SMF );
                sheet_to_chat();
            } else {
                llOwnerSay( "Your experience is not active here. Please reattach your HUD when you are in an area that allows the experience." );
                llRequestPermissions( llGetOwner(), PERMISSION_ATTACH );
            }
        }
    }
    
    run_time_permissions( integer perm ) {
        if ( perm & PERMISSION_ATTACH ) {
            if ( llGetAttached() ) {
                llDetachFromAvatar();
            }
        }
    }
    
    changed ( integer change )
    {
        if ( change & ( CHANGED_INVENTORY | CHANGED_ALLOWED_DROP ) ) {
            llResetScript();
        }
        if ( change & CHANGED_OWNER ) {
            llResetScript();
        }
        if ( change & CHANGED_COLOR ) {
            update_display();
        }
    }
}

