#include <amxmodx>
#include <amxmisc>
#include <hlstocks>
#include <reapi>

#define PLUGIN_NAME     "AG Pure"
#define PLUGIN_VERSION  "0.0.2"
#define PLUGIN_AUTHOR   "7mochi"

#pragma semicolon 1

#define AGVOTE_ACCEPTED 2

enum (+=34950) {
    TASK_CHECK_PLAYER = 7893
}

enum (+=1) {
    GAME_IDLE = 0,
    GAME_STARTING,
    GAME_RUNNING,
}

enum FileData {
    FileName[128],
    FileHash
}

new const g_fileList[][FileData] = {
    { "halflife.wad", 0x101DEA26 },
    { "decals.wad", 0x52859172 },
};

new QueryFileHook:g_hFiles[sizeof(g_fileList) * 4];
new g_iDefaultFileCount[MAX_PLAYERS + 1];
new bool:g_bHasDefaultFiles[MAX_PLAYERS + 1];
new g_iGameState;
new g_iPluginFlags;

new g_cvarAgStartMinPlayers;
new g_cvarAgMatchRunning;
new g_cvarAgPureLegacy;
new g_cvarAgPure;

public plugin_precache() {
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    g_cvarAgStartMinPlayers = get_cvar_pointer("sv_ag_start_minplayers");
    g_cvarAgMatchRunning = get_cvar_pointer("sv_ag_match_running");
    g_cvarAgPureLegacy = get_cvar_pointer("sv_ag_pure");

    if (g_cvarAgPureLegacy) {
        hook_cvar_change(g_cvarAgPureLegacy, "cvar_ag_pure_legacy_hook");
        g_cvarAgPure = create_cvar("sv_ag_pure_v2", "0", FCVAR_SERVER);
    } else {
        g_cvarAgPure = get_cvar_pointer("sv_ag_pure");
    }

    g_iPluginFlags = plugin_flags();

    g_iGameState = GAME_IDLE;

    register_message(get_user_msgid("Countdown"), "fw_msg_countdown");
    register_message(get_user_msgid("Settings"), "fw_msg_settings");
    register_message(get_user_msgid("Vote"), "fw_msg_vote");
    
    new szFileName[128];
    for (new i = 0; i < sizeof(g_fileList); i++) {
        new const szPaths[][] = {
            "",
            "../ag_addon/",
            "../ag_hd/",
            "../ag_spanish/"
        };

        for (new j = 0; j < sizeof(szPaths); j++) {
            if (j == 0) {
                copy(szFileName, charsmax(szFileName), g_fileList[i][FileName]);
            } else {
                formatex(szFileName, charsmax(szFileName), "%s%s", szPaths[j], g_fileList[i][FileName]);
            }

            if (g_iPluginFlags & AMX_FLAG_DEBUG) {
                server_print("[DEBUG] ag_pure.amxx - Registering file %s in plugin_init()", szFileName);
            }

            g_hFiles[i * sizeof(szPaths) + j] = RegisterQueryFile(szFileName, "handle_default_file_match", RES_TYPE_HASH_ANY);
        }
    }

    set_task(5.0, "check_player_status", TASK_CHECK_PLAYER);
}

public plugin_end() {
    for (new i = 0; i < sizeof(g_hFiles); i++) {
        UnRegisterQueryFile(g_hFiles[i]);
    }
}

public client_disconnected(iPlayer) {
    g_iDefaultFileCount[iPlayer] = 0;
    g_bHasDefaultFiles[iPlayer] = false;
}

public cvar_ag_pure_legacy_hook(pcvar, const szOldValue[], const szNewValue[]) {
    server_print("Warning: CVar ^"sv_ag_pure^" is deprecated. Use instead ^"sv_ag_pure_v2^"");
}

public fw_msg_countdown(iPlayer, iDestination, iEntity) {
    static iCount, iSound;
    iCount = get_msg_arg_int(1);
    iSound = get_msg_arg_int(2);

    if (iCount >= 9) {
        g_iGameState = GAME_STARTING;
    }

    if (iCount != -1 || iSound != 0)
        return;
    
    g_iGameState = GAME_RUNNING;
}

public fw_msg_settings(iPlayer, iDestination, iEntity) {
    static iMatchRunning;
    iMatchRunning = get_msg_arg_int(1);

    if (!iMatchRunning) {
        g_iGameState = GAME_IDLE;
    }
}

public fw_msg_vote(iPlayer, iDestination, iEntity) {
    static iStatus, szSetting[32];
    iStatus = get_msg_arg_int(1);
    get_msg_arg_string(5, szSetting, charsmax(szSetting));

    if (iStatus == AGVOTE_ACCEPTED) {
        if (equali(szSetting, "agstart") && get_playersnum() >= get_pcvar_num(g_cvarAgStartMinPlayers)) {
            // Reserved for future use
        } else if (equali(szSetting, "agabort")) {
            g_iGameState = GAME_IDLE;
        }
    }
}

public handle_default_file_match(const iPlayer, const iHash) {
    if (g_iPluginFlags & AMX_FLAG_DEBUG) {
        new szUsername[64];
        get_user_name(iPlayer, szUsername, charsmax(szUsername));
        server_print("[DEBUG] ag_pure.amxx - Execute handle_default_file_match() for player %s", szUsername);
    }
    
    for (new i = 0; i < sizeof(g_fileList); i++) {
        if (g_fileList[i][FileHash] == iHash) {
            g_iDefaultFileCount[iPlayer]++;
        }
    }

    if (g_iDefaultFileCount[iPlayer] == sizeof(g_fileList)) {
        g_bHasDefaultFiles[iPlayer] = true;
    }
}

public check_player_status() {
    if (g_iPluginFlags & AMX_FLAG_DEBUG) {
        server_print("[DEBUG] ag_pure.amxx - Execute check_player_status()");
    }

    for (new id = 1; id <= MaxClients; id++) {
        if (!is_user_connected(id))
            continue;
        
        if (get_pcvar_num(g_cvarAgPure) && get_pcvar_num(g_cvarAgMatchRunning) && g_iGameState == GAME_RUNNING && !hl_get_user_spectator(id) && !g_bHasDefaultFiles[id]) {
            rh_drop_client(id, "AG Pure: You must have the default files to play on this server.");
        }
    }
    
    set_task(5.0, "check_player_status", TASK_CHECK_PLAYER);
}
