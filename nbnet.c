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

#undef NBN_SerializeUInt
#undef NBN_SerializeUInt64
#undef NBN_SerializeInt
#undef NBN_SerializeFloat
#undef NBN_SerializeBool
#undef NBN_SerializeString
#undef NBN_SerializeBytes
#undef NBN_SerializePadding

void NBN_Driver_Init(void);
void NBN_SerializeUInt(NBN_Stream *stream, unsigned int value, unsigned int min, unsigned int max);
void NBN_SerializeUInt64(NBN_Stream *stream, uint64_t value);
void NBN_SerializeInt(NBN_Stream *stream, int value, int min, int max);
void NBN_SerializeFloat(NBN_Stream *stream, float value, float min, float max, int precision);
void NBN_SerializeBool(NBN_Stream *stream, bool value);
void NBN_SerializeString(NBN_Stream *stream, const char* value, unsigned int length);
void NBN_SerializeBytes(NBN_Stream *stream, uint8_t *value, unsigned int length);
void NBN_SerializePadding(NBN_Stream *stream);

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

void
NBN_SerializeUInt(NBN_Stream *stream, unsigned int value, unsigned int min, unsigned int max)
{
    ASSERTED_SERIALIZE(stream, value, min, max, stream->serialize_uint_func(stream, &value, min, max));
}

void
NBN_SerializeUInt64(NBN_Stream *stream, uint64_t value)
{
    stream->serialize_uint64_func(stream, &value);
}

void
NBN_SerializeInt(NBN_Stream *stream, int value, int min, int max)
{
    ASSERTED_SERIALIZE(stream, value, min, max, stream->serialize_int_func(stream, &value, min, max));
}

void
NBN_SerializeFloat(NBN_Stream *stream, float value, float min, float max, int precision)
{
    ASSERTED_SERIALIZE(stream, value, min, max, stream->serialize_float_func(stream, &value, min, max, precision));
}

void
NBN_SerializeBool(NBN_Stream *stream, bool value)
{
    ASSERTED_SERIALIZE(stream, value, 0, 1, stream->serialize_bool_func(stream, &value));
}

void
NBN_SerializeString(NBN_Stream *stream, const char* value, unsigned int length)
{
    NBN_SerializeBytes(stream, (uint8_t*)value, length);
}

void
NBN_SerializeBytes(NBN_Stream *stream, uint8_t *value, unsigned int length)
{
    stream->serialize_bytes_func(stream, value, length);
}

void
NBN_SerializePadding(NBN_Stream *stream)
{
    stream->serialize_padding_func(stream);
}
