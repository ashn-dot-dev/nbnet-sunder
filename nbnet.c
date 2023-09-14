#include <stdarg.h>
#include <stdio.h>

typedef enum NBN_LogType {
    NBN_LOG_INFO,
    NBN_LOG_ERROR,
    NBN_LOG_DEBUG,
    NBN_LOG_TRACE,
    NBN_LOG_WARNING,
} NBN_LogType;

void NBN_Log(NBN_LogType type, const char *fmt, ...);
#define NBN_LogInfo(...) NBN_Log(NBN_LOG_INFO, __VA_ARGS__)
#define NBN_LogError(...) NBN_Log(NBN_LOG_ERROR, __VA_ARGS__)
#define NBN_LogDebug(...) NBN_Log(NBN_LOG_DEBUG, __VA_ARGS__)
#define NBN_LogTrace(...) NBN_Log(NBN_LOG_TRACE, __VA_ARGS__)
#define NBN_LogWarning(...) NBN_Log(NBN_LOG_WARNING, __VA_ARGS__)

#define NBNET_IMPL
#include <nbnet.h>
#include <net_drivers/udp.h>

void NBN_Driver_Init(void);

void
NBN_Log(NBN_LogType type, const char *fmt, ...)
{
    static const char *strings[] = {
        [NBN_LOG_INFO] = "INFO",
        [NBN_LOG_ERROR] = "ERROR",
        [NBN_LOG_DEBUG] = "DEBUG",
        [NBN_LOG_TRACE] = "TRACE",
        [NBN_LOG_WARNING] = "WARNING",
    };

    va_list args;
    va_start(args, fmt);

    fprintf(stderr, "[nbnet %s] ", strings[type]);
    vfprintf(stderr, fmt, args);
    fprintf(stderr, "\n");

    va_end(args);
}

void
NBN_Driver_Init(void)
{
    NBN_UDP_Register();
}
