#include <amxmodx>
#include <amxmisc>
#include <reapi>

#define PLUGIN_NAME     "AG Pure"
#define PLUGIN_VERSION  "0.0.1"
#define PLUGIN_AUTHOR   "7mochi"

#pragma semicolon 1

enum (+=34950) {
    TASK_DROP_PLAYER = 7893
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
new g_iPluginFlags;

public plugin_init() {
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    g_iPluginFlags = plugin_flags();
    
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
}

public plugin_end() {
    for (new i = 0; i < sizeof(g_hFiles); i++) {
        UnRegisterQueryFile(g_hFiles[i]);
    }
}

public handle_default_file_match(const iPlayer, const iHash) {
    if (g_iPluginFlags & AMX_FLAG_DEBUG) {
        server_print("[DEBUG] ag_pure.amxx - Execute handle_default_file_match()");
    }

    new bool:bHashMatch = false;

    for (new i = 0; i < sizeof(g_fileList); i++) {
        if (g_fileList[i][FileHash] == iHash) {
            bHashMatch = true;
            break;
        }
    }

    if (!bHashMatch) {
        set_task(0.1, "drop_player", iPlayer);
    }
}

public drop_player(iPlayer) {
    if (g_iPluginFlags & AMX_FLAG_DEBUG) {
        server_print("[DEBUG] ag_pure.amxx - Execute drop_player()");
    }
    
    if (!is_user_connected(iPlayer))
        return PLUGIN_HANDLED;

    rh_drop_client(iPlayer, "AG Pure: You must have the default files to play on this server.");

    return PLUGIN_HANDLED;
}
