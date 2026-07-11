package miniaudio

foreign import lib "system:miniaudio"

VERSION_MAJOR :: 0
VERSION_MINOR :: 11
VERSION_REVISION :: 24
SIZEOF_PTR :: 8
TRUE :: 1
FALSE :: 0
SIMD_ALIGNMENT :: 32
MIN_CHANNELS :: 1
MAX_CHANNELS :: 254
MAX_FILTER_ORDER :: 8
MAX_LOG_CALLBACKS :: 4
CHANNEL_INDEX_NULL :: 255
DATA_SOURCE_SELF_MANAGED_RANGE_AND_LOOP_POINT :: 0x00000001
MAX_DEVICE_NAME_LENGTH :: 255
RESOURCE_MANAGER_MAX_JOB_THREAD_COUNT :: 64
MAX_NODE_BUS_COUNT :: 254
MAX_NODE_LOCAL_BUS_COUNT :: 2
NODE_BUS_COUNT_UNKNOWN :: 255
ENGINE_MAX_LISTENERS :: 4
int8 :: i8

uint8 :: u8

int16 :: i16

uint16 :: u16

int32 :: i32

uint32 :: u32

int64 :: i64

uint64 :: u64

uintptr :: uint64

bool8 :: uint8

bool32 :: uint32

/* These float types are not used universally by miniaudio. It's to simplify some macro expansion for atomic types. */
float :: f32

double :: f64

handle :: rawptr

ptr :: rawptr

proc_ :: proc "c" ()

pthread_t :: u64

pthread_mutex_t :: struct #raw_union {
	__data:  __pthread_mutex_s,
	__size:  [40]u8,
	__align: i64,
}

__pthread_mutex_s :: struct {
	__lock:           i32,
	__count:          u32,
	__owner:          i32,
	__nusers:         u32,
	__kind:           i32,
	__spins:          i16,
	__glibc_reserved: i16,
	__list:           __pthread_internal_list,
}

__pthread_internal_list :: struct {
	__prev: ^__pthread_internal_list,
	__next: ^__pthread_internal_list,
}

pthread_cond_t :: struct #raw_union {
	__data:  __pthread_cond_s,
	__size:  [48]u8,
	__align: i64,
}

__pthread_cond_s :: struct {
	__wseq:                 __atomic_wide_counter,
	__g1_start:             __atomic_wide_counter,
	__g_size:               [2]u32,
	__g1_orig_size:         u32,
	__wrefs:                u32,
	__g_signals:            [2]u32,
	__unused_initialized_1: u32,
	__unused_initialized_2: u32,
}

__atomic_wide_counter :: struct #raw_union {
	__value64: u64,
	__value32: struct {
		__low:  u32,
		__high: u32,
	},
}

wchar_win32 :: uint16

/*
Logging Levels
==============
Log levels are only used to give logging callbacks some context as to the severity of a log message
so they can do filtering. All log levels will be posted to registered logging callbacks. If you
don't want to output a certain log level you can discriminate against the log level in the callback.

MA_LOG_LEVEL_DEBUG
    Used for debugging. Useful for debug and test builds, but should be disabled in release builds.

MA_LOG_LEVEL_INFO
    Informational logging. Useful for debugging. This will never be called from within the data
    callback.

MA_LOG_LEVEL_WARNING
    Warnings. You should enable this in you development builds and action them when encountered. These
    logs usually indicate a potential problem or misconfiguration, but still allow you to keep
    running. This will never be called from within the data callback.

MA_LOG_LEVEL_ERROR
    Error logging. This will be fired when an operation fails and is subsequently aborted. This can
    be fired from within the data callback, in which case the device will be stopped. You should
    always have this log level enabled.
*/
log_level :: enum u32 {
	MA_LOG_LEVEL_DEBUG   = 4,
	MA_LOG_LEVEL_INFO    = 3,
	MA_LOG_LEVEL_WARNING = 2,
	MA_LOG_LEVEL_ERROR   = 1,
}

context_ :: struct {
	callbacks:               backend_callbacks,
	/* DirectSound, ALSA, etc. */
	backend:                 backend,
	pLog:                    ^log,
	/* Only used if the log is owned by the context. The pLog member will be set to &log in this case. */
	log:                     log,
	threadPriority:          thread_priority,
	threadStackSize:         uint,
	pUserData:               rawptr,
	allocationCallbacks:     allocation_callbacks,
	/* Used to make ma_context_get_devices() thread safe. */
	deviceEnumLock:          mutex,
	/* Used to make ma_context_get_device_info() thread safe. */
	deviceInfoLock:          mutex,
	/* Total capacity of pDeviceInfos. */
	deviceInfoCapacity:      uint32,
	playbackDeviceInfoCount: uint32,
	captureDeviceInfoCount:  uint32,
	/* Playback devices first, then capture. */
	pDeviceInfos:            ^device_info,
	using _:                 struct #raw_union {
		alsa:         struct {
			asoundSO:                               handle,
			snd_pcm_open:                           proc_,
			snd_pcm_close:                          proc_,
			snd_pcm_hw_params_sizeof:               proc_,
			snd_pcm_hw_params_any:                  proc_,
			snd_pcm_hw_params_set_format:           proc_,
			snd_pcm_hw_params_set_format_first:     proc_,
			snd_pcm_hw_params_get_format_mask:      proc_,
			snd_pcm_hw_params_set_channels:         proc_,
			snd_pcm_hw_params_set_channels_near:    proc_,
			snd_pcm_hw_params_set_channels_minmax:  proc_,
			snd_pcm_hw_params_set_rate_resample:    proc_,
			snd_pcm_hw_params_set_rate:             proc_,
			snd_pcm_hw_params_set_rate_near:        proc_,
			snd_pcm_hw_params_set_rate_minmax:      proc_,
			snd_pcm_hw_params_set_buffer_size_near: proc_,
			snd_pcm_hw_params_set_periods_near:     proc_,
			snd_pcm_hw_params_set_access:           proc_,
			snd_pcm_hw_params_get_format:           proc_,
			snd_pcm_hw_params_get_channels:         proc_,
			snd_pcm_hw_params_get_channels_min:     proc_,
			snd_pcm_hw_params_get_channels_max:     proc_,
			snd_pcm_hw_params_get_rate:             proc_,
			snd_pcm_hw_params_get_rate_min:         proc_,
			snd_pcm_hw_params_get_rate_max:         proc_,
			snd_pcm_hw_params_get_buffer_size:      proc_,
			snd_pcm_hw_params_get_periods:          proc_,
			snd_pcm_hw_params_get_access:           proc_,
			snd_pcm_hw_params_test_format:          proc_,
			snd_pcm_hw_params_test_channels:        proc_,
			snd_pcm_hw_params_test_rate:            proc_,
			snd_pcm_hw_params:                      proc_,
			snd_pcm_sw_params_sizeof:               proc_,
			snd_pcm_sw_params_current:              proc_,
			snd_pcm_sw_params_get_boundary:         proc_,
			snd_pcm_sw_params_set_avail_min:        proc_,
			snd_pcm_sw_params_set_start_threshold:  proc_,
			snd_pcm_sw_params_set_stop_threshold:   proc_,
			snd_pcm_sw_params:                      proc_,
			snd_pcm_format_mask_sizeof:             proc_,
			snd_pcm_format_mask_test:               proc_,
			snd_pcm_get_chmap:                      proc_,
			snd_pcm_state:                          proc_,
			snd_pcm_prepare:                        proc_,
			snd_pcm_start:                          proc_,
			snd_pcm_drop:                           proc_,
			snd_pcm_drain:                          proc_,
			snd_pcm_reset:                          proc_,
			snd_device_name_hint:                   proc_,
			snd_device_name_get_hint:               proc_,
			snd_card_get_index:                     proc_,
			snd_device_name_free_hint:              proc_,
			snd_pcm_mmap_begin:                     proc_,
			snd_pcm_mmap_commit:                    proc_,
			snd_pcm_recover:                        proc_,
			snd_pcm_readi:                          proc_,
			snd_pcm_writei:                         proc_,
			snd_pcm_avail:                          proc_,
			snd_pcm_avail_update:                   proc_,
			snd_pcm_wait:                           proc_,
			snd_pcm_nonblock:                       proc_,
			snd_pcm_info:                           proc_,
			snd_pcm_info_sizeof:                    proc_,
			snd_pcm_info_get_name:                  proc_,
			snd_pcm_poll_descriptors:               proc_,
			snd_pcm_poll_descriptors_count:         proc_,
			snd_pcm_poll_descriptors_revents:       proc_,
			snd_config_update_free_global:          proc_,
			internalDeviceEnumLock:                 mutex,
			useVerboseDeviceEnumeration:            bool32,
		},
		pulse:        struct {
			pulseSO:                            handle,
			pa_mainloop_new:                    proc_,
			pa_mainloop_free:                   proc_,
			pa_mainloop_quit:                   proc_,
			pa_mainloop_get_api:                proc_,
			pa_mainloop_iterate:                proc_,
			pa_mainloop_wakeup:                 proc_,
			pa_threaded_mainloop_new:           proc_,
			pa_threaded_mainloop_free:          proc_,
			pa_threaded_mainloop_start:         proc_,
			pa_threaded_mainloop_stop:          proc_,
			pa_threaded_mainloop_lock:          proc_,
			pa_threaded_mainloop_unlock:        proc_,
			pa_threaded_mainloop_wait:          proc_,
			pa_threaded_mainloop_signal:        proc_,
			pa_threaded_mainloop_accept:        proc_,
			pa_threaded_mainloop_get_retval:    proc_,
			pa_threaded_mainloop_get_api:       proc_,
			pa_threaded_mainloop_in_thread:     proc_,
			pa_threaded_mainloop_set_name:      proc_,
			pa_context_new:                     proc_,
			pa_context_unref:                   proc_,
			pa_context_connect:                 proc_,
			pa_context_disconnect:              proc_,
			pa_context_set_state_callback:      proc_,
			pa_context_get_state:               proc_,
			pa_context_get_sink_info_list:      proc_,
			pa_context_get_source_info_list:    proc_,
			pa_context_get_sink_info_by_name:   proc_,
			pa_context_get_source_info_by_name: proc_,
			pa_operation_unref:                 proc_,
			pa_operation_get_state:             proc_,
			pa_channel_map_init_extend:         proc_,
			pa_channel_map_valid:               proc_,
			pa_channel_map_compatible:          proc_,
			pa_stream_new:                      proc_,
			pa_stream_unref:                    proc_,
			pa_stream_connect_playback:         proc_,
			pa_stream_connect_record:           proc_,
			pa_stream_disconnect:               proc_,
			pa_stream_get_state:                proc_,
			pa_stream_get_sample_spec:          proc_,
			pa_stream_get_channel_map:          proc_,
			pa_stream_get_buffer_attr:          proc_,
			pa_stream_set_buffer_attr:          proc_,
			pa_stream_get_device_name:          proc_,
			pa_stream_set_write_callback:       proc_,
			pa_stream_set_read_callback:        proc_,
			pa_stream_set_suspended_callback:   proc_,
			pa_stream_set_moved_callback:       proc_,
			pa_stream_is_suspended:             proc_,
			pa_stream_flush:                    proc_,
			pa_stream_drain:                    proc_,
			pa_stream_is_corked:                proc_,
			pa_stream_cork:                     proc_,
			pa_stream_trigger:                  proc_,
			pa_stream_begin_write:              proc_,
			pa_stream_write:                    proc_,
			pa_stream_peek:                     proc_,
			pa_stream_drop:                     proc_,
			pa_stream_writable_size:            proc_,
			pa_stream_readable_size:            proc_,
			/*pa_mainloop**/
			pMainLoop:                          ptr,
			/*pa_context**/
			pPulseContext:                      ptr,
			/* Set when the context is initialized. Used by devices for their local pa_context objects. */
			pApplicationName:                   ^u8,
			/* Set when the context is initialized. Used by devices for their local pa_context objects. */
			pServerName:                        ^u8,
		},
		jack:         struct {
			jackSO:                        handle,
			jack_client_open:              proc_,
			jack_client_close:             proc_,
			jack_client_name_size:         proc_,
			jack_set_process_callback:     proc_,
			jack_set_buffer_size_callback: proc_,
			jack_on_shutdown:              proc_,
			jack_get_sample_rate:          proc_,
			jack_get_buffer_size:          proc_,
			jack_get_ports:                proc_,
			jack_activate:                 proc_,
			jack_deactivate:               proc_,
			jack_connect:                  proc_,
			jack_port_register:            proc_,
			jack_port_name:                proc_,
			jack_port_get_buffer:          proc_,
			jack_free:                     proc_,
			pClientName:                   ^u8,
			tryStartServer:                bool32,
		},
		null_backend: struct {
			_unused: i32,
		},
	},
	using _:                 struct #raw_union {
		posix:   struct {
			_unused: i32,
		},
		_unused: i32,
	},
}

device :: struct {
	pContext:                  ^context_,
	type:                      device_type,
	sampleRate:                uint32,
	/* The state of the device is variable and can change at any time on any thread. Must be used atomically. */
	state:                     atomic_device_state,
	/* Set once at initialization time and should not be changed after. */
	onData:                    device_data_proc,
	/* Set once at initialization time and should not be changed after. */
	onNotification:            device_notification_proc,
	/* DEPRECATED. Use the notification callback instead. Set once at initialization time and should not be changed after. */
	onStop:                    stop_proc,
	/* Application defined data. */
	pUserData:                 rawptr,
	startStopLock:             mutex,
	wakeupEvent:               event,
	startEvent:                event,
	stopEvent:                 event,
	thread:                    thread,
	/* This is set by the worker thread after it's finished doing a job. */
	workResult:                result,
	/* When set to true, uninitializing the device will also uninitialize the context. Set to true when NULL is passed into ma_device_init(). */
	isOwnerOfContext:          bool8,
	noPreSilencedOutputBuffer: bool8,
	noClip:                    bool8,
	noDisableDenormals:        bool8,
	noFixedSizedCallback:      bool8,
	/* Linear 0..1. Can be read and written simultaneously by different threads. Must be used atomically. */
	masterVolumeFactor:        atomic_float,
	/* Intermediary buffer for duplex device on asynchronous backends. */
	duplexRB:                  duplex_rb,
	resampling:                struct {
		algorithm:        resample_algorithm,
		pBackendVTable:   ^resampling_backend_vtable,
		pBackendUserData: rawptr,
		linear:           struct {
			lpfOrder: uint32,
		},
	},
	playback:                  struct {
		/* Set to NULL if using default ID, otherwise set to the address of "id". */
		pID:                             ^device_id,
		/* If using an explicit device, will be set to a copy of the ID used for initialization. Otherwise cleared to 0. */
		id:                              device_id,
		/* Maybe temporary. Likely to be replaced with a query API. */
		name:                            [256]u8,
		/* Set to whatever was passed in when the device was initialized. */
		shareMode:                       share_mode,
		format:                          format,
		channels:                        uint32,
		channelMap:                      [254]channel,
		internalFormat:                  format,
		internalChannels:                uint32,
		internalSampleRate:              uint32,
		internalChannelMap:              [254]channel,
		internalPeriodSizeInFrames:      uint32,
		internalPeriods:                 uint32,
		channelMixMode:                  channel_mix_mode,
		calculateLFEFromSpatialChannels: bool32,
		converter:                       data_converter,
		/* For implementing fixed sized buffer callbacks. Will be null if using variable sized callbacks. */
		pIntermediaryBuffer:             rawptr,
		intermediaryBufferCap:           uint32,
		/* How many valid frames are sitting in the intermediary buffer. */
		intermediaryBufferLen:           uint32,
		/* In external format. Can be null. */
		pInputCache:                     rawptr,
		inputCacheCap:                   uint64,
		inputCacheConsumed:              uint64,
		inputCacheRemaining:             uint64,
	},
	capture:                   struct {
		/* Set to NULL if using default ID, otherwise set to the address of "id". */
		pID:                             ^device_id,
		/* If using an explicit device, will be set to a copy of the ID used for initialization. Otherwise cleared to 0. */
		id:                              device_id,
		/* Maybe temporary. Likely to be replaced with a query API. */
		name:                            [256]u8,
		/* Set to whatever was passed in when the device was initialized. */
		shareMode:                       share_mode,
		format:                          format,
		channels:                        uint32,
		channelMap:                      [254]channel,
		internalFormat:                  format,
		internalChannels:                uint32,
		internalSampleRate:              uint32,
		internalChannelMap:              [254]channel,
		internalPeriodSizeInFrames:      uint32,
		internalPeriods:                 uint32,
		channelMixMode:                  channel_mix_mode,
		calculateLFEFromSpatialChannels: bool32,
		converter:                       data_converter,
		/* For implementing fixed sized buffer callbacks. Will be null if using variable sized callbacks. */
		pIntermediaryBuffer:             rawptr,
		intermediaryBufferCap:           uint32,
		/* How many valid frames are sitting in the intermediary buffer. */
		intermediaryBufferLen:           uint32,
	},
	using _:                   struct #raw_union {
		alsa:        struct {
			/*snd_pcm_t**/
			pPCMPlayback:                ptr,
			/*snd_pcm_t**/
			pPCMCapture:                 ptr,
			/*struct pollfd**/
			pPollDescriptorsPlayback:    rawptr,
			/*struct pollfd**/
			pPollDescriptorsCapture:     rawptr,
			pollDescriptorCountPlayback: i32,
			pollDescriptorCountCapture:  i32,
			/* eventfd for waking up from poll() when the playback device is stopped. */
			wakeupfdPlayback:            i32,
			/* eventfd for waking up from poll() when the capture device is stopped. */
			wakeupfdCapture:             i32,
			isUsingMMapPlayback:         bool8,
			isUsingMMapCapture:          bool8,
		},
		pulse:       struct {
			/*pa_mainloop**/
			pMainLoop:       ptr,
			/*pa_context**/
			pPulseContext:   ptr,
			/*pa_stream**/
			pStreamPlayback: ptr,
			/*pa_stream**/
			pStreamCapture:  ptr,
		},
		jack:        struct {
			/*jack_client_t**/
			pClient:                     ptr,
			/*jack_port_t**/
			ppPortsPlayback:             ^ptr,
			/*jack_port_t**/
			ppPortsCapture:              ^ptr,
			/* Typed as a float because JACK is always floating point. */
			pIntermediaryBufferPlayback: ^f32,
			pIntermediaryBufferCapture:  ^f32,
		},
		null_device: struct {
			deviceThread:                         thread,
			operationEvent:                       event,
			operationCompletionEvent:             event,
			operationSemaphore:                   semaphore,
			operation:                            uint32,
			operationResult:                      result,
			timer:                                timer,
			priorRunTime:                         f64,
			currentPeriodFramesRemainingPlayback: uint32,
			currentPeriodFramesRemainingCapture:  uint32,
			lastProcessedFramePlayback:           uint64,
			lastProcessedFrameCapture:            uint64,
			/* Read and written by multiple threads. Must be used atomically, and must be 32-bit for compiler compatibility. */
			isStarted:                            atomic_bool32,
		},
	},
}

channel :: uint8

_ma_channel_position :: enum u32 {
	MA_CHANNEL_NONE,
	MA_CHANNEL_MONO,
	MA_CHANNEL_FRONT_LEFT,
	MA_CHANNEL_FRONT_RIGHT,
	MA_CHANNEL_FRONT_CENTER,
	MA_CHANNEL_LFE,
	MA_CHANNEL_BACK_LEFT,
	MA_CHANNEL_BACK_RIGHT,
	MA_CHANNEL_FRONT_LEFT_CENTER,
	MA_CHANNEL_FRONT_RIGHT_CENTER,
	MA_CHANNEL_BACK_CENTER,
	MA_CHANNEL_SIDE_LEFT,
	MA_CHANNEL_SIDE_RIGHT,
	MA_CHANNEL_TOP_CENTER,
	MA_CHANNEL_TOP_FRONT_LEFT,
	MA_CHANNEL_TOP_FRONT_CENTER,
	MA_CHANNEL_TOP_FRONT_RIGHT,
	MA_CHANNEL_TOP_BACK_LEFT,
	MA_CHANNEL_TOP_BACK_CENTER,
	MA_CHANNEL_TOP_BACK_RIGHT,
	MA_CHANNEL_AUX_0,
	MA_CHANNEL_AUX_1,
	MA_CHANNEL_AUX_2,
	MA_CHANNEL_AUX_3,
	MA_CHANNEL_AUX_4,
	MA_CHANNEL_AUX_5,
	MA_CHANNEL_AUX_6,
	MA_CHANNEL_AUX_7,
	MA_CHANNEL_AUX_8,
	MA_CHANNEL_AUX_9,
	MA_CHANNEL_AUX_10,
	MA_CHANNEL_AUX_11,
	MA_CHANNEL_AUX_12,
	MA_CHANNEL_AUX_13,
	MA_CHANNEL_AUX_14,
	MA_CHANNEL_AUX_15,
	MA_CHANNEL_AUX_16,
	MA_CHANNEL_AUX_17,
	MA_CHANNEL_AUX_18,
	MA_CHANNEL_AUX_19,
	MA_CHANNEL_AUX_20,
	MA_CHANNEL_AUX_21,
	MA_CHANNEL_AUX_22,
	MA_CHANNEL_AUX_23,
	MA_CHANNEL_AUX_24,
	MA_CHANNEL_AUX_25,
	MA_CHANNEL_AUX_26,
	MA_CHANNEL_AUX_27,
	MA_CHANNEL_AUX_28,
	MA_CHANNEL_AUX_29,
	MA_CHANNEL_AUX_30,
	MA_CHANNEL_AUX_31,
	/* Count. */
	MA_CHANNEL_POSITION_COUNT,
	/* Aliases. */
	MA_CHANNEL_LEFT = 2,
	/* Aliases. */
	MA_CHANNEL_RIGHT,
}

result :: enum i32 {
	MA_SUCCESS,
	/* A generic error. */
	MA_ERROR = -1,
	MA_INVALID_ARGS = -2,
	MA_INVALID_OPERATION = -3,
	MA_OUT_OF_MEMORY = -4,
	MA_OUT_OF_RANGE = -5,
	MA_ACCESS_DENIED = -6,
	MA_DOES_NOT_EXIST = -7,
	MA_ALREADY_EXISTS = -8,
	MA_TOO_MANY_OPEN_FILES = -9,
	MA_INVALID_FILE = -10,
	MA_TOO_BIG = -11,
	MA_PATH_TOO_LONG = -12,
	MA_NAME_TOO_LONG = -13,
	MA_NOT_DIRECTORY = -14,
	MA_IS_DIRECTORY = -15,
	MA_DIRECTORY_NOT_EMPTY = -16,
	MA_AT_END = -17,
	MA_NO_SPACE = -18,
	MA_BUSY = -19,
	MA_IO_ERROR = -20,
	MA_INTERRUPT = -21,
	MA_UNAVAILABLE = -22,
	MA_ALREADY_IN_USE = -23,
	MA_BAD_ADDRESS = -24,
	MA_BAD_SEEK = -25,
	MA_BAD_PIPE = -26,
	MA_DEADLOCK = -27,
	MA_TOO_MANY_LINKS = -28,
	MA_NOT_IMPLEMENTED = -29,
	MA_NO_MESSAGE = -30,
	MA_BAD_MESSAGE = -31,
	MA_NO_DATA_AVAILABLE = -32,
	MA_INVALID_DATA = -33,
	MA_TIMEOUT = -34,
	MA_NO_NETWORK = -35,
	MA_NOT_UNIQUE = -36,
	MA_NOT_SOCKET = -37,
	MA_NO_ADDRESS = -38,
	MA_BAD_PROTOCOL = -39,
	MA_PROTOCOL_UNAVAILABLE = -40,
	MA_PROTOCOL_NOT_SUPPORTED = -41,
	MA_PROTOCOL_FAMILY_NOT_SUPPORTED = -42,
	MA_ADDRESS_FAMILY_NOT_SUPPORTED = -43,
	MA_SOCKET_NOT_SUPPORTED = -44,
	MA_CONNECTION_RESET = -45,
	MA_ALREADY_CONNECTED = -46,
	MA_NOT_CONNECTED = -47,
	MA_CONNECTION_REFUSED = -48,
	MA_NO_HOST = -49,
	MA_IN_PROGRESS = -50,
	MA_CANCELLED = -51,
	MA_MEMORY_ALREADY_MAPPED = -52,
	/* General non-standard errors. */
	MA_CRC_MISMATCH = -100,
	/* General miniaudio-specific errors. */
	MA_FORMAT_NOT_SUPPORTED = -200,
	/* General miniaudio-specific errors. */
	MA_DEVICE_TYPE_NOT_SUPPORTED = -201,
	/* General miniaudio-specific errors. */
	MA_SHARE_MODE_NOT_SUPPORTED = -202,
	/* General miniaudio-specific errors. */
	MA_NO_BACKEND = -203,
	/* General miniaudio-specific errors. */
	MA_NO_DEVICE = -204,
	/* General miniaudio-specific errors. */
	MA_API_NOT_FOUND = -205,
	/* General miniaudio-specific errors. */
	MA_INVALID_DEVICE_CONFIG = -206,
	/* General miniaudio-specific errors. */
	MA_LOOP = -207,
	/* General miniaudio-specific errors. */
	MA_BACKEND_NOT_ENABLED = -208,
	/* State errors. */
	MA_DEVICE_NOT_INITIALIZED = -300,
	/* State errors. */
	MA_DEVICE_ALREADY_INITIALIZED = -301,
	/* State errors. */
	MA_DEVICE_NOT_STARTED = -302,
	/* State errors. */
	MA_DEVICE_NOT_STOPPED = -303,
	/* Operation errors. */
	MA_FAILED_TO_INIT_BACKEND = -400,
	/* Operation errors. */
	MA_FAILED_TO_OPEN_BACKEND_DEVICE = -401,
	/* Operation errors. */
	MA_FAILED_TO_START_BACKEND_DEVICE = -402,
	/* Operation errors. */
	MA_FAILED_TO_STOP_BACKEND_DEVICE = -403,
}

stream_format :: enum u32 {
	stream_format_pcm,
}

stream_layout :: enum u32 {
	stream_layout_interleaved,
	stream_layout_deinterleaved,
}

dither_mode :: enum u32 {
	dither_mode_none,
	dither_mode_rectangle,
	dither_mode_triangle,
}

format :: enum u32 {
	/* Mainly used for indicating an error, but also used as the default for the output format for decoders. */
	format_unknown,
	format_u8,
	/* Seems to be the most widely supported format. */
	format_s16,
	/* Tightly packed. 3 bytes per sample. */
	format_s24,
	format_s32,
	format_f32,
	format_count,
}

standard_sample_rate :: enum u32 {
	/* Most common */
	standard_sample_rate_48000  = 48000,
	standard_sample_rate_44100  = 44100,
	/* Lows */
	standard_sample_rate_32000  = 32000,
	standard_sample_rate_24000  = 24000,
	standard_sample_rate_22050  = 22050,
	/* Highs */
	standard_sample_rate_88200  = 88200,
	standard_sample_rate_96000  = 96000,
	standard_sample_rate_176400 = 176400,
	standard_sample_rate_192000 = 192000,
	/* Extreme lows */
	standard_sample_rate_16000  = 16000,
	standard_sample_rate_11025  = 11025,
	standard_sample_rate_8000   = 8000,
	/* Extreme highs */
	standard_sample_rate_352800 = 352800,
	standard_sample_rate_384000 = 384000,
	standard_sample_rate_min    = 8000,
	standard_sample_rate_max    = 384000,
	/* Need to maintain the count manually. Make sure this is updated if items are added to enum. */
	standard_sample_rate_count  = 14,
}

channel_mix_mode :: enum u32 {
	/* Simple averaging based on the plane(s) the channel is sitting on. */
	channel_mix_mode_rectangular,
	/* Drop excess channels; zeroed out extra channels. */
	channel_mix_mode_simple,
	/* Use custom weights specified in ma_channel_converter_config. */
	channel_mix_mode_custom_weights,
	channel_mix_mode_default = 0,
}

standard_channel_map :: enum u32 {
	standard_channel_map_microsoft,
	standard_channel_map_alsa,
	/* Based off AIFF. */
	standard_channel_map_rfc3551,
	standard_channel_map_flac,
	standard_channel_map_vorbis,
	/* FreeBSD's sound(4). */
	standard_channel_map_sound4,
	/* www.sndio.org/tips.html */
	standard_channel_map_sndio,
	/* https://webaudio.github.io/web-audio-api/#ChannelOrdering. Only 1, 2, 4 and 6 channels are defined, but can fill in the gaps with logical assumptions. */
	standard_channel_map_webaudio = 3,
	standard_channel_map_default = 0,
}

performance_profile :: enum u32 {
	performance_profile_low_latency,
	performance_profile_conservative,
}

allocation_callbacks :: struct {
	pUserData: rawptr,
	onMalloc:  proc "c" (_: uint, _: rawptr) -> rawptr,
	onRealloc: proc "c" (_: rawptr, _: uint, _: rawptr) -> rawptr,
	onFree:    proc "c" (_: rawptr, _: rawptr),
}

lcg :: struct {
	state: uint32,
}

atomic_uint32 :: struct {
	value: uint32,
}

atomic_int32 :: struct {
	value: int32,
}

atomic_uint64 :: struct {
	value: uint64,
}

atomic_float :: struct {
	value: float,
}

atomic_bool32 :: struct {
	value: bool32,
}

/* Spinlocks are 32-bit for compatibility reasons. */
spinlock :: uint32

/* Thread priorities should be ordered such that the default priority of the worker thread is 0. */
thread_priority :: enum i32 {
	thread_priority_idle = -5,
	thread_priority_lowest,
	thread_priority_low,
	thread_priority_normal,
	thread_priority_high,
	thread_priority_highest,
	thread_priority_realtime,
	thread_priority_default = 0,
}

thread :: pthread_t

mutex :: pthread_mutex_t

event :: struct {
	value: uint32,
	lock:  pthread_mutex_t,
	cond:  pthread_cond_t,
}

semaphore :: struct {
	value: i32,
	lock:  pthread_mutex_t,
	cond:  pthread_cond_t,
}

/*
The callback for handling log messages.


Parameters
----------
pUserData (in)
    The user data pointer that was passed into ma_log_register_callback().

logLevel (in)
    The log level. This can be one of the following:

    +----------------------+
    | Log Level            |
    +----------------------+
    | MA_LOG_LEVEL_DEBUG   |
    | MA_LOG_LEVEL_INFO    |
    | MA_LOG_LEVEL_WARNING |
    | MA_LOG_LEVEL_ERROR   |
    +----------------------+

pMessage (in)
    The log message.
*/
log_callback_proc :: proc "c" (_: rawptr, _: uint32, _: cstring)

log_callback :: struct {
	onLog:     log_callback_proc,
	pUserData: rawptr,
}

log :: struct {
	callbacks:           [4]log_callback,
	callbackCount:       uint32,
	/* Need to store these persistently because ma_log_postv() might need to allocate a buffer on the heap. */
	allocationCallbacks: allocation_callbacks,
	/* For thread safety just to make it easier and safer for the logging implementation. */
	lock:                mutex,
}

__va_list_tag :: struct {
	gp_offset:         u32,
	fp_offset:         u32,
	overflow_arg_area: rawptr,
	reg_save_area:     rawptr,
}

/**************************************************************************************************************************************************************

Biquad Filtering

**************************************************************************************************************************************************************/
biquad_coefficient :: struct #raw_union {
	f32: f32,
	s32: int32,
}

biquad_config :: struct {
	format:   format,
	channels: uint32,
	b0:       f64,
	b1:       f64,
	b2:       f64,
	a0:       f64,
	a1:       f64,
	a2:       f64,
}

biquad :: struct {
	format:    format,
	channels:  uint32,
	b0:        biquad_coefficient,
	b1:        biquad_coefficient,
	b2:        biquad_coefficient,
	a1:        biquad_coefficient,
	a2:        biquad_coefficient,
	pR1:       ^biquad_coefficient,
	pR2:       ^biquad_coefficient,
	/* Memory management. */
	_pHeap:    rawptr,
	_ownsHeap: bool32,
}

/**************************************************************************************************************************************************************

Low-Pass Filtering

**************************************************************************************************************************************************************/
lpf1_config :: struct {
	format:          format,
	channels:        uint32,
	sampleRate:      uint32,
	cutoffFrequency: f64,
	q:               f64,
}

/**************************************************************************************************************************************************************

Low-Pass Filtering

**************************************************************************************************************************************************************/
lpf2_config :: lpf1_config

lpf1 :: struct {
	format:    format,
	channels:  uint32,
	a:         biquad_coefficient,
	pR1:       ^biquad_coefficient,
	/* Memory management. */
	_pHeap:    rawptr,
	_ownsHeap: bool32,
}

lpf2 :: struct {
	/* The second order low-pass filter is implemented as a biquad filter. */
	bq: biquad,
}

lpf_config :: struct {
	format:          format,
	channels:        uint32,
	sampleRate:      uint32,
	cutoffFrequency: f64,
	/* If set to 0, will be treated as a passthrough (no filtering will be applied). */
	order:           uint32,
}

lpf :: struct {
	format:     format,
	channels:   uint32,
	sampleRate: uint32,
	lpf1Count:  uint32,
	lpf2Count:  uint32,
	pLPF1:      ^lpf1,
	pLPF2:      ^lpf2,
	/* Memory management. */
	_pHeap:     rawptr,
	_ownsHeap:  bool32,
}

/**************************************************************************************************************************************************************

High-Pass Filtering

**************************************************************************************************************************************************************/
hpf1_config :: struct {
	format:          format,
	channels:        uint32,
	sampleRate:      uint32,
	cutoffFrequency: f64,
	q:               f64,
}

/**************************************************************************************************************************************************************

High-Pass Filtering

**************************************************************************************************************************************************************/
hpf2_config :: hpf1_config

hpf1 :: struct {
	format:    format,
	channels:  uint32,
	a:         biquad_coefficient,
	pR1:       ^biquad_coefficient,
	/* Memory management. */
	_pHeap:    rawptr,
	_ownsHeap: bool32,
}

hpf2 :: struct {
	/* The second order high-pass filter is implemented as a biquad filter. */
	bq: biquad,
}

hpf_config :: struct {
	format:          format,
	channels:        uint32,
	sampleRate:      uint32,
	cutoffFrequency: f64,
	/* If set to 0, will be treated as a passthrough (no filtering will be applied). */
	order:           uint32,
}

hpf :: struct {
	format:     format,
	channels:   uint32,
	sampleRate: uint32,
	hpf1Count:  uint32,
	hpf2Count:  uint32,
	pHPF1:      ^hpf1,
	pHPF2:      ^hpf2,
	/* Memory management. */
	_pHeap:     rawptr,
	_ownsHeap:  bool32,
}

/**************************************************************************************************************************************************************

Band-Pass Filtering

**************************************************************************************************************************************************************/
bpf2_config :: struct {
	format:          format,
	channels:        uint32,
	sampleRate:      uint32,
	cutoffFrequency: f64,
	q:               f64,
}

bpf2 :: struct {
	/* The second order band-pass filter is implemented as a biquad filter. */
	bq: biquad,
}

bpf_config :: struct {
	format:          format,
	channels:        uint32,
	sampleRate:      uint32,
	cutoffFrequency: f64,
	/* If set to 0, will be treated as a passthrough (no filtering will be applied). */
	order:           uint32,
}

bpf :: struct {
	format:    format,
	channels:  uint32,
	bpf2Count: uint32,
	pBPF2:     ^bpf2,
	/* Memory management. */
	_pHeap:    rawptr,
	_ownsHeap: bool32,
}

/**************************************************************************************************************************************************************

Notching Filter

**************************************************************************************************************************************************************/
notch2_config :: struct {
	format:     format,
	channels:   uint32,
	sampleRate: uint32,
	q:          f64,
	frequency:  f64,
}

/**************************************************************************************************************************************************************

Notching Filter

**************************************************************************************************************************************************************/
notch_config :: notch2_config

notch2 :: struct {
	bq: biquad,
}

/**************************************************************************************************************************************************************

Peaking EQ Filter

**************************************************************************************************************************************************************/
peak2_config :: struct {
	format:     format,
	channels:   uint32,
	sampleRate: uint32,
	gainDB:     f64,
	q:          f64,
	frequency:  f64,
}

/**************************************************************************************************************************************************************

Peaking EQ Filter

**************************************************************************************************************************************************************/
peak_config :: peak2_config

peak2 :: struct {
	bq: biquad,
}

/**************************************************************************************************************************************************************

Low Shelf Filter

**************************************************************************************************************************************************************/
loshelf2_config :: struct {
	format:     format,
	channels:   uint32,
	sampleRate: uint32,
	gainDB:     f64,
	shelfSlope: f64,
	frequency:  f64,
}

/**************************************************************************************************************************************************************

Low Shelf Filter

**************************************************************************************************************************************************************/
loshelf_config :: loshelf2_config

loshelf2 :: struct {
	bq: biquad,
}

/**************************************************************************************************************************************************************

High Shelf Filter

**************************************************************************************************************************************************************/
hishelf2_config :: struct {
	format:     format,
	channels:   uint32,
	sampleRate: uint32,
	gainDB:     f64,
	shelfSlope: f64,
	frequency:  f64,
}

/**************************************************************************************************************************************************************

High Shelf Filter

**************************************************************************************************************************************************************/
hishelf_config :: hishelf2_config

hishelf2 :: struct {
	bq: biquad,
}

/*
Delay
*/
delay_config :: struct {
	channels:      uint32,
	sampleRate:    uint32,
	delayInFrames: uint32,
	/* Set to true to delay the start of the output; false otherwise. */
	delayStart:    bool32,
	/* 0..1. Default = 1. */
	wet:           f32,
	/* 0..1. Default = 1. */
	dry:           f32,
	/* 0..1. Default = 0 (no feedback). Feedback decay. Use this for echo. */
	decay:         f32,
}

delay :: struct {
	config:             delay_config,
	/* Feedback is written to this cursor. Always equal or in front of the read cursor. */
	cursor:             uint32,
	bufferSizeInFrames: uint32,
	pBuffer:            ^f32,
}

/* Gainer for smooth volume changes. */
gainer_config :: struct {
	channels:           uint32,
	smoothTimeInFrames: uint32,
}

gainer :: struct {
	config:       gainer_config,
	t:            uint32,
	masterVolume: f32,
	pOldGains:    ^f32,
	pNewGains:    ^f32,
	/* Memory management. */
	_pHeap:       rawptr,
	_ownsHeap:    bool32,
}

/* Stereo panner. */
pan_mode :: enum u32 {
	/* Does not blend one side with the other. Technically just a balance. Compatible with other popular audio engines and therefore the default. */
	pan_mode_balance,
	/* A true pan. The sound from one side will "move" to the other side and blend with it. */
	pan_mode_pan,
}

panner_config :: struct {
	format:   format,
	channels: uint32,
	mode:     pan_mode,
	pan:      f32,
}

panner :: struct {
	format:   format,
	channels: uint32,
	mode:     pan_mode,
	/* -1..1 where 0 is no pan, -1 is left side, +1 is right side. Defaults to 0. */
	pan:      f32,
}

/* Fader. */
fader_config :: struct {
	format:     format,
	channels:   uint32,
	sampleRate: uint32,
}

fader :: struct {
	config:         fader_config,
	/* If volumeBeg and volumeEnd is equal to 1, no fading happens (ma_fader_process_pcm_frames() will run as a passthrough). */
	volumeBeg:      f32,
	volumeEnd:      f32,
	/* The total length of the fade. */
	lengthInFrames: uint64,
	/* The current time in frames. Incremented by ma_fader_process_pcm_frames(). Signed because it'll be offset by startOffsetInFrames in set_fade_ex(). */
	cursorInFrames: int64,
}

/* Spatializer. */
vec3f :: struct {
	x: f32,
	y: f32,
	z: f32,
}

atomic_vec3f :: struct {
	v:    vec3f,
	lock: spinlock,
}

attenuation_model :: enum u32 {
	/* No distance attenuation and no spatialization. */
	attenuation_model_none,
	/* Equivalent to OpenAL's AL_INVERSE_DISTANCE_CLAMPED. */
	attenuation_model_inverse,
	/* Linear attenuation. Equivalent to OpenAL's AL_LINEAR_DISTANCE_CLAMPED. */
	attenuation_model_linear,
	/* Exponential attenuation. Equivalent to OpenAL's AL_EXPONENT_DISTANCE_CLAMPED. */
	attenuation_model_exponential,
}

positioning :: enum u32 {
	positioning_absolute,
	positioning_relative,
}

handedness :: enum u32 {
	handedness_right,
	handedness_left,
}

spatializer_listener_config :: struct {
	channelsOut:             uint32,
	pChannelMapOut:          ^channel,
	/* Defaults to right. Forward is -1 on the Z axis. In a left handed system, forward is +1 on the Z axis. */
	handedness:              handedness,
	coneInnerAngleInRadians: f32,
	coneOuterAngleInRadians: f32,
	coneOuterGain:           f32,
	speedOfSound:            f32,
	worldUp:                 vec3f,
}

spatializer_listener :: struct {
	config:    spatializer_listener_config,
	/* The absolute position of the listener. */
	position:  atomic_vec3f,
	/* The direction the listener is facing. The world up vector is config.worldUp. */
	direction: atomic_vec3f,
	velocity:  atomic_vec3f,
	isEnabled: bool32,
	/* Memory management. */
	_ownsHeap: bool32,
	_pHeap:    rawptr,
}

spatializer_config :: struct {
	channelsIn:                   uint32,
	channelsOut:                  uint32,
	pChannelMapIn:                ^channel,
	attenuationModel:             attenuation_model,
	positioning:                  positioning,
	/* Defaults to right. Forward is -1 on the Z axis. In a left handed system, forward is +1 on the Z axis. */
	handedness:                   handedness,
	minGain:                      f32,
	maxGain:                      f32,
	minDistance:                  f32,
	maxDistance:                  f32,
	rolloff:                      f32,
	coneInnerAngleInRadians:      f32,
	coneOuterAngleInRadians:      f32,
	coneOuterGain:                f32,
	/* Set to 0 to disable doppler effect. */
	dopplerFactor:                f32,
	/* Set to 0 to disable directional attenuation. */
	directionalAttenuationFactor: f32,
	/* The minimal scaling factor to apply to channel gains when accounting for the direction of the sound relative to the listener. Must be in the range of 0..1. Smaller values means more aggressive directional panning, larger values means more subtle directional panning. */
	minSpatializationChannelGain: f32,
	/* When the gain of a channel changes during spatialization, the transition will be linearly interpolated over this number of frames. */
	gainSmoothTimeInFrames:       uint32,
}

spatializer :: struct {
	channelsIn:                   uint32,
	channelsOut:                  uint32,
	pChannelMapIn:                ^channel,
	attenuationModel:             attenuation_model,
	positioning:                  positioning,
	/* Defaults to right. Forward is -1 on the Z axis. In a left handed system, forward is +1 on the Z axis. */
	handedness:                   handedness,
	minGain:                      f32,
	maxGain:                      f32,
	minDistance:                  f32,
	maxDistance:                  f32,
	rolloff:                      f32,
	coneInnerAngleInRadians:      f32,
	coneOuterAngleInRadians:      f32,
	coneOuterGain:                f32,
	/* Set to 0 to disable doppler effect. */
	dopplerFactor:                f32,
	/* Set to 0 to disable directional attenuation. */
	directionalAttenuationFactor: f32,
	/* When the gain of a channel changes during spatialization, the transition will be linearly interpolated over this number of frames. */
	gainSmoothTimeInFrames:       uint32,
	position:                     atomic_vec3f,
	direction:                    atomic_vec3f,
	/* For doppler effect. */
	velocity:                     atomic_vec3f,
	/* Will be updated by ma_spatializer_process_pcm_frames() and can be used by higher level functions to apply a pitch shift for doppler effect. */
	dopplerPitch:                 f32,
	minSpatializationChannelGain: f32,
	/* For smooth gain transitions. */
	gainer:                       gainer,
	/* An offset of _pHeap. Used by ma_spatializer_process_pcm_frames() to store new channel gains. The number of elements in this array is equal to config.channelsOut. */
	pNewChannelGainsOut:          ^f32,
	/* Memory management. */
	_pHeap:                       rawptr,
	_ownsHeap:                    bool32,
}

/**************************************************************************************************************************************************************

Resampling

**************************************************************************************************************************************************************/
linear_resampler_config :: struct {
	format:           format,
	channels:         uint32,
	sampleRateIn:     uint32,
	sampleRateOut:    uint32,
	/* The low-pass filter order. Setting this to 0 will disable low-pass filtering. */
	lpfOrder:         uint32,
	/* 0..1. Defaults to 1. 1 = Half the sampling frequency (Nyquist Frequency), 0.5 = Quarter the sampling frequency (half Nyquest Frequency), etc. */
	lpfNyquistFactor: f64,
}

linear_resampler :: struct {
	config:        linear_resampler_config,
	inAdvanceInt:  uint32,
	inAdvanceFrac: uint32,
	inTimeInt:     uint32,
	inTimeFrac:    uint32,
	/* The previous input frame. */
	x0:            struct #raw_union {
		f32: ^f32,
		s16: ^int16,
	},
	/* The next input frame. */
	x1:            struct #raw_union {
		f32: ^f32,
		s16: ^int16,
	},
	lpf:           lpf,
	/* Memory management. */
	_pHeap:        rawptr,
	_ownsHeap:     bool32,
}

resampler_config :: struct {
	/* Must be either ma_format_f32 or ma_format_s16. */
	format:           format,
	channels:         uint32,
	sampleRateIn:     uint32,
	sampleRateOut:    uint32,
	/* When set to ma_resample_algorithm_custom, pBackendVTable will be used. */
	algorithm:        resample_algorithm,
	pBackendVTable:   ^resampling_backend_vtable,
	pBackendUserData: rawptr,
	linear:           struct {
		lpfOrder: uint32,
	},
}

resampling_backend_vtable :: struct {
	onGetHeapSize:                 proc "c" (_: rawptr, _: ^resampler_config, _: ^uint) -> result,
	onInit:                        proc "c" (_: rawptr, _: ^resampler_config, _: rawptr, _: ^^ma_resampling_backend) -> result,
	onUninit:                      proc "c" (_: rawptr, _: ^ma_resampling_backend, _: ^allocation_callbacks),
	onProcess:                     proc "c" (_: rawptr, _: ^ma_resampling_backend, _: rawptr, _: ^uint64, _: rawptr, _: ^uint64) -> result,
	/* Optional. Rate changes will be disabled. */
	onSetRate:                     proc "c" (_: rawptr, _: ^ma_resampling_backend, _: uint32, _: uint32) -> result,
	/* Optional. Latency will be reported as 0. */
	onGetInputLatency:             proc "c" (_: rawptr, _: ^ma_resampling_backend) -> uint64,
	/* Optional. Latency will be reported as 0. */
	onGetOutputLatency:            proc "c" (_: rawptr, _: ^ma_resampling_backend) -> uint64,
	/* Optional. Latency mitigation will be disabled. */
	onGetRequiredInputFrameCount:  proc "c" (_: rawptr, _: ^ma_resampling_backend, _: uint64, _: ^uint64) -> result,
	/* Optional. Latency mitigation will be disabled. */
	onGetExpectedOutputFrameCount: proc "c" (_: rawptr, _: ^ma_resampling_backend, _: uint64, _: ^uint64) -> result,
	onReset:                       proc "c" (_: rawptr, _: ^ma_resampling_backend) -> result,
}

resample_algorithm :: enum u32 {
	/* Fastest, lowest quality. Optional low-pass filtering. Default. */
	resample_algorithm_linear,
	resample_algorithm_custom,
}

resampler :: struct {
	pBackend:         ^ma_resampling_backend,
	pBackendVTable:   ^resampling_backend_vtable,
	pBackendUserData: rawptr,
	format:           format,
	channels:         uint32,
	sampleRateIn:     uint32,
	sampleRateOut:    uint32,
	/* State for stock resamplers so we can avoid a malloc. For stock resamplers, pBackend will point here. */
	state:            struct #raw_union {
		linear: linear_resampler,
	},
	/* Memory management. */
	_pHeap:           rawptr,
	_ownsHeap:        bool32,
}

/**************************************************************************************************************************************************************

Channel Conversion

**************************************************************************************************************************************************************/
channel_conversion_path :: enum u32 {
	channel_conversion_path_unknown,
	channel_conversion_path_passthrough,
	/* Converting to mono. */
	channel_conversion_path_mono_out,
	/* Converting from mono. */
	channel_conversion_path_mono_in,
	/* Simple shuffle. Will use this when all channels are present in both input and output channel maps, but just in a different order. */
	channel_conversion_path_shuffle,
	/* Blended based on weights. */
	channel_conversion_path_weights,
}

mono_expansion_mode :: enum u32 {
	/* The default. */
	mono_expansion_mode_duplicate,
	/* Average the mono channel across all channels. */
	mono_expansion_mode_average,
	/* Duplicate to the left and right channels only and ignore the others. */
	mono_expansion_mode_stereo_only,
	mono_expansion_mode_default = 0,
}

channel_converter_config :: struct {
	format:                          format,
	channelsIn:                      uint32,
	channelsOut:                     uint32,
	pChannelMapIn:                   ^channel,
	pChannelMapOut:                  ^channel,
	mixingMode:                      channel_mix_mode,
	/* When an output LFE channel is present, but no input LFE, set to true to set the output LFE to the average of all spatial channels (LR, FR, etc.). Ignored when an input LFE is present. */
	calculateLFEFromSpatialChannels: bool32,
	/* [in][out]. Only used when mixingMode is set to ma_channel_mix_mode_custom_weights. */
	ppWeights:                       ^^f32,
}

channel_converter :: struct {
	format:         format,
	channelsIn:     uint32,
	channelsOut:    uint32,
	mixingMode:     channel_mix_mode,
	conversionPath: channel_conversion_path,
	pChannelMapIn:  ^channel,
	pChannelMapOut: ^channel,
	/* Indexed by output channel index. */
	pShuffleTable:  ^uint8,
	/* [in][out] */
	weights:        struct #raw_union {
		f32: ^^f32,
		s16: ^^int32,
	},
	/* Memory management. */
	_pHeap:         rawptr,
	_ownsHeap:      bool32,
}

/**************************************************************************************************************************************************************

Data Conversion

**************************************************************************************************************************************************************/
data_converter_config :: struct {
	formatIn:                        format,
	formatOut:                       format,
	channelsIn:                      uint32,
	channelsOut:                     uint32,
	sampleRateIn:                    uint32,
	sampleRateOut:                   uint32,
	pChannelMapIn:                   ^channel,
	pChannelMapOut:                  ^channel,
	ditherMode:                      dither_mode,
	channelMixMode:                  channel_mix_mode,
	/* When an output LFE channel is present, but no input LFE, set to true to set the output LFE to the average of all spatial channels (LR, FR, etc.). Ignored when an input LFE is present. */
	calculateLFEFromSpatialChannels: bool32,
	/* [in][out]. Only used when mixingMode is set to ma_channel_mix_mode_custom_weights. */
	ppChannelWeights:                ^^f32,
	allowDynamicSampleRate:          bool32,
	resampling:                      resampler_config,
}

data_converter_execution_path :: enum u32 {
	/* No conversion. */
	data_converter_execution_path_passthrough,
	/* Only format conversion. */
	data_converter_execution_path_format_only,
	/* Only channel conversion. */
	data_converter_execution_path_channels_only,
	/* Only resampling. */
	data_converter_execution_path_resample_only,
	/* All conversions, but resample as the first step. */
	data_converter_execution_path_resample_first,
	/* All conversions, but channels as the first step. */
	data_converter_execution_path_channels_first,
}

data_converter :: struct {
	formatIn:                format,
	formatOut:               format,
	channelsIn:              uint32,
	channelsOut:             uint32,
	sampleRateIn:            uint32,
	sampleRateOut:           uint32,
	ditherMode:              dither_mode,
	/* The execution path the data converter will follow when processing. */
	executionPath:           data_converter_execution_path,
	channelConverter:        channel_converter,
	resampler:               resampler,
	hasPreFormatConversion:  bool8,
	hasPostFormatConversion: bool8,
	hasChannelConverter:     bool8,
	hasResampler:            bool8,
	isPassthrough:           bool8,
	/* Memory management. */
	_ownsHeap:               bool8,
	_pHeap:                  rawptr,
}

data_source_vtable :: struct {
	onRead:          proc "c" (_: ^ma_data_source, _: rawptr, _: uint64, _: ^uint64) -> result,
	onSeek:          proc "c" (_: ^ma_data_source, _: uint64) -> result,
	onGetDataFormat: proc "c" (_: ^ma_data_source, _: ^format, _: ^uint32, _: ^uint32, _: ^channel, _: uint) -> result,
	onGetCursor:     proc "c" (_: ^ma_data_source, _: ^uint64) -> result,
	onGetLength:     proc "c" (_: ^ma_data_source, _: ^uint64) -> result,
	onSetLooping:    proc "c" (_: ^ma_data_source, _: bool32) -> result,
	flags:           uint32,
}

data_source_get_next_proc :: proc "c" (_: ^ma_data_source) -> ^ma_data_source

data_source_config :: struct {
	vtable: ^data_source_vtable,
}

data_source_base :: struct {
	vtable:           ^data_source_vtable,
	rangeBegInFrames: uint64,
	/* Set to -1 for unranged (default). */
	rangeEndInFrames: uint64,
	/* Relative to rangeBegInFrames. */
	loopBegInFrames:  uint64,
	/* Relative to rangeBegInFrames. Set to -1 for the end of the range. */
	loopEndInFrames:  uint64,
	/* When non-NULL, the data source being initialized will act as a proxy and will route all operations to pCurrent. Used in conjunction with pNext/onGetNext for seamless chaining. */
	pCurrent:         ^ma_data_source,
	/* When set to NULL, onGetNext will be used. */
	pNext:            ^ma_data_source,
	/* Will be used when pNext is NULL. If both are NULL, no next will be used. */
	onGetNext:        data_source_get_next_proc,
	isLooping:        bool32,
}

audio_buffer_ref :: struct {
	ds:           data_source_base,
	format:       format,
	channels:     uint32,
	sampleRate:   uint32,
	cursor:       uint64,
	sizeInFrames: uint64,
	pData:        rawptr,
}

audio_buffer_config :: struct {
	format:              format,
	channels:            uint32,
	sampleRate:          uint32,
	sizeInFrames:        uint64,
	/* If set to NULL, will allocate a block of memory for you. */
	pData:               rawptr,
	allocationCallbacks: allocation_callbacks,
}

audio_buffer :: struct {
	ref:                 audio_buffer_ref,
	allocationCallbacks: allocation_callbacks,
	/* Used to control whether or not miniaudio owns the data buffer. If set to true, pData will be freed in ma_audio_buffer_uninit(). */
	ownsData:            bool32,
	/* For allocating a buffer with the memory located directly after the other memory of the structure. */
	_pExtraData:         [1]uint8,
}

paged_audio_buffer_page :: struct {
	pNext:        ^paged_audio_buffer_page,
	sizeInFrames: uint64,
	pAudioData:   [1]uint8,
}

paged_audio_buffer_data :: struct {
	format:   format,
	channels: uint32,
	/* Dummy head for the lock-free algorithm. Always has a size of 0. */
	head:     paged_audio_buffer_page,
	/* Never null. Initially set to &head. */
	pTail:    ^paged_audio_buffer_page,
}

paged_audio_buffer_config :: struct {
	/* Must not be null. */
	pData: ^paged_audio_buffer_data,
}

paged_audio_buffer :: struct {
	ds:             data_source_base,
	/* Audio data is read from here. Cannot be null. */
	pData:          ^paged_audio_buffer_data,
	pCurrent:       ^paged_audio_buffer_page,
	/* Relative to the current page. */
	relativeCursor: uint64,
	absoluteCursor: uint64,
}

/************************************************************************************************************************************************************

Ring Buffer

************************************************************************************************************************************************************/
rb :: struct {
	pBuffer:                rawptr,
	subbufferSizeInBytes:   uint32,
	subbufferCount:         uint32,
	subbufferStrideInBytes: uint32,
	/* Most significant bit is the loop flag. Lower 31 bits contains the actual offset in bytes. Must be used atomically. */
	encodedReadOffset:      uint32,
	/* Most significant bit is the loop flag. Lower 31 bits contains the actual offset in bytes. Must be used atomically. */
	encodedWriteOffset:     uint32,
	/* Used to know whether or not miniaudio is responsible for free()-ing the buffer. */
	ownsBuffer:             bool8,
	/* When set, clears the acquired write buffer before returning from ma_rb_acquire_write(). */
	clearOnWriteAcquire:    bool8,
	allocationCallbacks:    allocation_callbacks,
}

pcm_rb :: struct {
	ds:         data_source_base,
	rb:         rb,
	format:     format,
	channels:   uint32,
	/* Not required for the ring buffer itself, but useful for associating the data with some sample rate, particularly for data sources. */
	sampleRate: uint32,
}

/*
The idea of the duplex ring buffer is to act as the intermediary buffer when running two asynchronous devices in a duplex set up. The
capture device writes to it, and then a playback device reads from it.

At the moment this is just a simple naive implementation, but in the future I want to implement some dynamic resampling to seamlessly
handle desyncs. Note that the API is work in progress and may change at any time in any version.

The size of the buffer is based on the capture side since that's what'll be written to the buffer. It is based on the capture period size
in frames. The internal sample rate of the capture device is also needed in order to calculate the size.
*/
duplex_rb :: struct {
	rb: pcm_rb,
}

/*
Fence
=====
This locks while the counter is larger than 0. Counter can be incremented and decremented by any
thread, but care needs to be taken when waiting. It is possible for one thread to acquire the
fence just as another thread returns from ma_fence_wait().

The idea behind a fence is to allow you to wait for a group of operations to complete. When an
operation starts, the counter is incremented which locks the fence. When the operation completes,
the fence will be released which decrements the counter. ma_fence_wait() will block until the
counter hits zero.

If threading is disabled, ma_fence_wait() will spin on the counter.
*/
fence :: struct {
	e:       event,
	counter: uint32,
}

async_notification_callbacks :: struct {
	onSignal: proc "c" (_: ^ma_async_notification),
}

/*
Simple polling notification.

This just sets a variable when the notification has been signalled which is then polled with ma_async_notification_poll_is_signalled()
*/
async_notification_poll :: struct {
	cb:        async_notification_callbacks,
	signalled: bool32,
}

/*
Event Notification

This uses an ma_event. If threading is disabled (MA_NO_THREADING), initialization will fail.
*/
async_notification_event :: struct {
	cb: async_notification_callbacks,
	e:  event,
}

/*
Slot Allocator
--------------
The idea of the slot allocator is for it to be used in conjunction with a fixed sized buffer. You use the slot allocator to allocate an index that can be used
as the insertion point for an object.

Slots are reference counted to help mitigate the ABA problem in the lock-free queue we use for tracking jobs.

The slot index is stored in the low 32 bits. The reference counter is stored in the high 32 bits:

    +-----------------+-----------------+
    | 32 Bits         | 32 Bits         |
    +-----------------+-----------------+
    | Reference Count | Slot Index      |
    +-----------------+-----------------+
*/
slot_allocator_config :: struct {
	/* The number of slots to make available. */
	capacity: uint32,
}

slot_allocator_group :: struct {
	/* Must be used atomically because the allocation and freeing routines need to make copies of this which must never be optimized away by the compiler. */
	bitfield: uint32,
}

slot_allocator :: struct {
	/* Slots are grouped in chunks of 32. */
	pGroups:   ^slot_allocator_group,
	/* 32 bits for reference counting for ABA mitigation. */
	pSlots:    ^uint32,
	/* Allocation count. */
	count:     uint32,
	capacity:  uint32,
	/* Memory management. */
	_ownsHeap: bool32,
	_pHeap:    rawptr,
}

job :: struct {
	/* 8 bytes. We encode the job code into the slot allocation data to save space. */
	toc:   struct #raw_union {
		breakup:    struct {
			/* Job type. */
			code:     uint16,
			/* Index into a ma_slot_allocator. */
			slot:     uint16,
			refcount: uint32,
		},
		allocation: uint64,
	},
	/* refcount + slot for the next item. Does not include the job code. */
	next:  uint64,
	/* Execution order. Used to create a data dependency and ensure a job is executed in order. Usage is contextual depending on the job type. */
	order: uint32,
	data:  struct #raw_union {
		custom:          struct {
			proc_: job_proc,
			data0: uintptr,
			data1: uintptr,
		},
		resourceManager: struct #raw_union {
			loadDataBufferNode: struct {
				/*ma_resource_manager**/
				pResourceManager:  rawptr,
				/*ma_resource_manager_data_buffer_node**/
				pDataBufferNode:   rawptr,
				pFilePath:         ^u8,
				pFilePathW:        ^i32,
				/* Resource manager data source flags that were used when initializing the data buffer. */
				flags:             uint32,
				/* Signalled when the data buffer has been initialized and the format/channels/rate can be retrieved. */
				pInitNotification: ^ma_async_notification,
				/* Signalled when the data buffer has been fully decoded. Will be passed through to MA_JOB_TYPE_RESOURCE_MANAGER_PAGE_DATA_BUFFER_NODE when decoding. */
				pDoneNotification: ^ma_async_notification,
				/* Released when initialization of the decoder is complete. */
				pInitFence:        ^fence,
				/* Released if initialization of the decoder fails. Passed through to PAGE_DATA_BUFFER_NODE untouched if init is successful. */
				pDoneFence:        ^fence,
			},
			freeDataBufferNode: struct {
				/*ma_resource_manager**/
				pResourceManager:  rawptr,
				/*ma_resource_manager_data_buffer_node**/
				pDataBufferNode:   rawptr,
				pDoneNotification: ^ma_async_notification,
				pDoneFence:        ^fence,
			},
			pageDataBufferNode: struct {
				/*ma_resource_manager**/
				pResourceManager:  rawptr,
				/*ma_resource_manager_data_buffer_node**/
				pDataBufferNode:   rawptr,
				/*ma_decoder**/
				pDecoder:          rawptr,
				/* Signalled when the data buffer has been fully decoded. */
				pDoneNotification: ^ma_async_notification,
				/* Passed through from LOAD_DATA_BUFFER_NODE and released when the data buffer completes decoding or an error occurs. */
				pDoneFence:        ^fence,
			},
			loadDataBuffer:     struct {
				/*ma_resource_manager_data_buffer**/
				pDataBuffer:             rawptr,
				/* Signalled when the data buffer has been initialized and the format/channels/rate can be retrieved. */
				pInitNotification:       ^ma_async_notification,
				/* Signalled when the data buffer has been fully decoded. */
				pDoneNotification:       ^ma_async_notification,
				/* Released when the data buffer has been initialized and the format/channels/rate can be retrieved. */
				pInitFence:              ^fence,
				/* Released when the data buffer has been fully decoded. */
				pDoneFence:              ^fence,
				rangeBegInPCMFrames:     uint64,
				rangeEndInPCMFrames:     uint64,
				loopPointBegInPCMFrames: uint64,
				loopPointEndInPCMFrames: uint64,
				isLooping:               uint32,
			},
			freeDataBuffer:     struct {
				/*ma_resource_manager_data_buffer**/
				pDataBuffer:       rawptr,
				pDoneNotification: ^ma_async_notification,
				pDoneFence:        ^fence,
			},
			loadDataStream:     struct {
				/*ma_resource_manager_data_stream**/
				pDataStream:       rawptr,
				/* Allocated when the job is posted, freed by the job thread after loading. */
				pFilePath:         ^u8,
				/* ^ As above ^. Only used if pFilePath is NULL. */
				pFilePathW:        ^i32,
				initialSeekPoint:  uint64,
				/* Signalled after the first two pages have been decoded and frames can be read from the stream. */
				pInitNotification: ^ma_async_notification,
				pInitFence:        ^fence,
			},
			freeDataStream:     struct {
				/*ma_resource_manager_data_stream**/
				pDataStream:       rawptr,
				pDoneNotification: ^ma_async_notification,
				pDoneFence:        ^fence,
			},
			pageDataStream:     struct {
				/*ma_resource_manager_data_stream**/
				pDataStream: rawptr,
				/* The index of the page to decode into. */
				pageIndex:   uint32,
			},
			seekDataStream:     struct {
				/*ma_resource_manager_data_stream**/
				pDataStream: rawptr,
				frameIndex:  uint64,
			},
		},
		device:          struct #raw_union {
			aaudio: struct #raw_union {
				reroute: struct {
					/*ma_device**/
					pDevice:    rawptr,
					/*ma_device_type*/
					deviceType: uint32,
				},
			},
		},
	},
}

/*
Callback for processing a job. Each job type will have their own processing callback which will be
called by ma_job_process().
*/
job_proc :: proc "c" (_: ^job) -> result

/* When a job type is added here an callback needs to be added go "g_jobVTable" in the implementation section. */
job_type :: enum u32 {
	/* Miscellaneous. */
	MA_JOB_TYPE_QUIT,
	/* Miscellaneous. */
	MA_JOB_TYPE_CUSTOM,
	/* Resource Manager. */
	MA_JOB_TYPE_RESOURCE_MANAGER_LOAD_DATA_BUFFER_NODE,
	/* Resource Manager. */
	MA_JOB_TYPE_RESOURCE_MANAGER_FREE_DATA_BUFFER_NODE,
	/* Resource Manager. */
	MA_JOB_TYPE_RESOURCE_MANAGER_PAGE_DATA_BUFFER_NODE,
	/* Resource Manager. */
	MA_JOB_TYPE_RESOURCE_MANAGER_LOAD_DATA_BUFFER,
	/* Resource Manager. */
	MA_JOB_TYPE_RESOURCE_MANAGER_FREE_DATA_BUFFER,
	/* Resource Manager. */
	MA_JOB_TYPE_RESOURCE_MANAGER_LOAD_DATA_STREAM,
	/* Resource Manager. */
	MA_JOB_TYPE_RESOURCE_MANAGER_FREE_DATA_STREAM,
	/* Resource Manager. */
	MA_JOB_TYPE_RESOURCE_MANAGER_PAGE_DATA_STREAM,
	/* Resource Manager. */
	MA_JOB_TYPE_RESOURCE_MANAGER_SEEK_DATA_STREAM,
	/* Device. */
	MA_JOB_TYPE_DEVICE_AAUDIO_REROUTE,
	/* Count. Must always be last. */
	MA_JOB_TYPE_COUNT,
}

/*
When set, ma_job_queue_next() will not wait and no semaphore will be signaled in
ma_job_queue_post(). ma_job_queue_next() will return MA_NO_DATA_AVAILABLE if nothing is available.

This flag should always be used for platforms that do not support multithreading.
*/
job_queue_flags :: enum u32 {
	MA_JOB_QUEUE_FLAG_NON_BLOCKING = 1,
}

job_queue_config :: struct {
	flags:    uint32,
	/* The maximum number of jobs that can fit in the queue at a time. */
	capacity: uint32,
}

job_queue :: struct {
	/* Flags passed in at initialization time. */
	flags:     uint32,
	/* The maximum number of jobs that can fit in the queue at a time. Set by the config. */
	capacity:  uint32,
	/* The first item in the list. Required for removing from the top of the list. */
	head:      uint64,
	/* The last item in the list. Required for appending to the end of the list. */
	tail:      uint64,
	/* Only used when MA_JOB_QUEUE_FLAG_NON_BLOCKING is unset. */
	sem:       semaphore,
	allocator: slot_allocator,
	pJobs:     ^job,
	lock:      spinlock,
	/* Memory management. */
	_pHeap:    rawptr,
	_ownsHeap: bool32,
}

device_state :: enum u32 {
	device_state_uninitialized,
	/* The device's default state after initialization. */
	device_state_stopped,
	/* The device is started and is requesting and/or delivering audio data. */
	device_state_started,
	/* Transitioning from a stopped state to started. */
	device_state_starting,
	/* Transitioning from a started state to stopped. */
	device_state_stopping,
}

atomic_device_state :: struct {
	value: device_state,
}

/* Backend enums must be in priority order. */
backend :: enum u32 {
	backend_wasapi,
	backend_dsound,
	backend_winmm,
	backend_coreaudio,
	backend_sndio,
	backend_audio4,
	backend_oss,
	backend_pulseaudio,
	backend_alsa,
	backend_jack,
	backend_aaudio,
	backend_opensl,
	backend_webaudio,
	/* <-- Custom backend, with callbacks defined by the context config. */
	backend_custom,
	/* <-- Must always be the last item. Lowest priority, and used as the terminator for backend enumeration. */
	backend_null,
}

/*
Device job thread. This is used by backends that require asynchronous processing of certain
operations. It is not used by all backends.

The device job thread is made up of a thread and a job queue. You can post a job to the thread with
ma_device_job_thread_post(). The thread will do the processing of the job.
*/
device_job_thread_config :: struct {
	/* Set this to true if you want to process jobs yourself. */
	noThread:         bool32,
	jobQueueCapacity: uint32,
	jobQueueFlags:    uint32,
}

device_job_thread :: struct {
	thread:     thread,
	jobQueue:   job_queue,
	_hasThread: bool32,
}

/* Device notification types. */
device_notification_type :: enum u32 {
	device_notification_type_started,
	device_notification_type_stopped,
	device_notification_type_rerouted,
	device_notification_type_interruption_began,
	device_notification_type_interruption_ended,
	device_notification_type_unlocked,
}

device_notification :: struct {
	pDevice: ^device,
	type:    device_notification_type,
	data:    struct #raw_union {
		started:      struct {
			_unused: i32,
		},
		stopped:      struct {
			_unused: i32,
		},
		rerouted:     struct {
			_unused: i32,
		},
		interruption: struct {
			_unused: i32,
		},
	},
}

/*
The notification callback for when the application should be notified of a change to the device.

This callback is used for notifying the application of changes such as when the device has started,
stopped, rerouted or an interruption has occurred. Note that not all backends will post all
notification types. For example, some backends will perform automatic stream routing without any
kind of notification to the host program which means miniaudio will never know about it and will
never be able to fire the rerouted notification. You should keep this in mind when designing your
program.

The stopped notification will *not* get fired when a device is rerouted.


Parameters
----------
pNotification (in)
    A pointer to a structure containing information about the event. Use the `pDevice` member of
    this object to retrieve the relevant device. The `type` member can be used to discriminate
    against each of the notification types.


Remarks
-------
Do not restart or uninitialize the device from the callback.

Not all notifications will be triggered by all backends, however the started and stopped events
should be reliable for all backends. Some backends do not have a good way to detect device
stoppages due to unplugging the device which may result in the stopped callback not getting
fired. This has been observed with at least one BSD variant.

The rerouted notification is fired *after* the reroute has occurred. The stopped notification will
*not* get fired when a device is rerouted. The following backends are known to do automatic stream
rerouting, but do not have a way to be notified of the change:

  * DirectSound

The interruption notifications are used on mobile platforms for detecting when audio is interrupted
due to things like an incoming phone call. Currently this is only implemented on iOS. None of the
Android backends will report this notification.
*/
device_notification_proc :: proc "c" (_: ^device_notification)

/*
The callback for processing audio data from the device.

The data callback is fired by miniaudio whenever the device needs to have more data delivered to a playback device, or when a capture device has some data
available. This is called as soon as the backend asks for more data which means it may be called with inconsistent frame counts. You cannot assume the
callback will be fired with a consistent frame count.


Parameters
----------
pDevice (in)
    A pointer to the relevant device.

pOutput (out)
    A pointer to the output buffer that will receive audio data that will later be played back through the speakers. This will be non-null for a playback or
    full-duplex device and null for a capture and loopback device.

pInput (in)
    A pointer to the buffer containing input data from a recording device. This will be non-null for a capture, full-duplex or loopback device and null for a
    playback device.

frameCount (in)
    The number of PCM frames to process. Note that this will not necessarily be equal to what you requested when you initialized the device. The
    `periodSizeInFrames` and `periodSizeInMilliseconds` members of the device config are just hints, and are not necessarily exactly what you'll get. You must
    not assume this will always be the same value each time the callback is fired.


Remarks
-------
You cannot stop and start the device from inside the callback or else you'll get a deadlock. You must also not uninitialize the device from inside the
callback. The following APIs cannot be called from inside the callback:

    ma_device_init()
    ma_device_init_ex()
    ma_device_uninit()
    ma_device_start()
    ma_device_stop()

The proper way to stop the device is to call `ma_device_stop()` from a different thread, normally the main application thread.
*/
device_data_proc :: proc "c" (_: ^device, _: rawptr, _: rawptr, _: uint32)

/*
DEPRECATED. Use ma_device_notification_proc instead.

The callback for when the device has been stopped.

This will be called when the device is stopped explicitly with `ma_device_stop()` and also called implicitly when the device is stopped through external forces
such as being unplugged or an internal error occurring.


Parameters
----------
pDevice (in)
    A pointer to the device that has just stopped.


Remarks
-------
Do not restart or uninitialize the device from the callback.
*/
stop_proc :: proc "c" (_: ^device)

device_type :: enum u32 {
	device_type_playback = 1,
	device_type_capture,
	/* 3 */
	device_type_duplex,
	device_type_loopback,
}

share_mode :: enum u32 {
	share_mode_shared,
	share_mode_exclusive,
}

/* iOS/tvOS/watchOS session categories. */
ios_session_category :: enum u32 {
	/* AVAudioSessionCategoryPlayAndRecord. */
	ios_session_category_default,
	/* Leave the session category unchanged. */
	ios_session_category_none,
	/* AVAudioSessionCategoryAmbient */
	ios_session_category_ambient,
	/* AVAudioSessionCategorySoloAmbient */
	ios_session_category_solo_ambient,
	/* AVAudioSessionCategoryPlayback */
	ios_session_category_playback,
	/* AVAudioSessionCategoryRecord */
	ios_session_category_record,
	/* AVAudioSessionCategoryPlayAndRecord */
	ios_session_category_play_and_record,
	/* AVAudioSessionCategoryMultiRoute */
	ios_session_category_multi_route,
}

/* iOS/tvOS/watchOS session category options */
ios_session_category_option :: enum u32 {
	/* AVAudioSessionCategoryOptionMixWithOthers */
	ios_session_category_option_mix_with_others = 1,
	/* AVAudioSessionCategoryOptionDuckOthers */
	ios_session_category_option_duck_others,
	/* AVAudioSessionCategoryOptionAllowBluetooth */
	ios_session_category_option_allow_bluetooth = 4,
	/* AVAudioSessionCategoryOptionDefaultToSpeaker */
	ios_session_category_option_default_to_speaker = 8,
	/* AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers */
	ios_session_category_option_interrupt_spoken_audio_and_mix_with_others = 17,
	/* AVAudioSessionCategoryOptionAllowBluetoothA2DP */
	ios_session_category_option_allow_bluetooth_a2dp = 32,
	/* AVAudioSessionCategoryOptionAllowAirPlay */
	ios_session_category_option_allow_air_play = 64,
}

/* OpenSL stream types. */
opensl_stream_type :: enum u32 {
	/* Leaves the stream type unset. */
	opensl_stream_type_default,
	/* SL_ANDROID_STREAM_VOICE */
	opensl_stream_type_voice,
	/* SL_ANDROID_STREAM_SYSTEM */
	opensl_stream_type_system,
	/* SL_ANDROID_STREAM_RING */
	opensl_stream_type_ring,
	/* SL_ANDROID_STREAM_MEDIA */
	opensl_stream_type_media,
	/* SL_ANDROID_STREAM_ALARM */
	opensl_stream_type_alarm,
	/* SL_ANDROID_STREAM_NOTIFICATION */
	opensl_stream_type_notification,
}

/* OpenSL recording presets. */
opensl_recording_preset :: enum u32 {
	/* Leaves the input preset unset. */
	opensl_recording_preset_default,
	/* SL_ANDROID_RECORDING_PRESET_GENERIC */
	opensl_recording_preset_generic,
	/* SL_ANDROID_RECORDING_PRESET_CAMCORDER */
	opensl_recording_preset_camcorder,
	/* SL_ANDROID_RECORDING_PRESET_VOICE_RECOGNITION */
	opensl_recording_preset_voice_recognition,
	/* SL_ANDROID_RECORDING_PRESET_VOICE_COMMUNICATION */
	opensl_recording_preset_voice_communication,
	/* SL_ANDROID_RECORDING_PRESET_UNPROCESSED */
	opensl_recording_preset_voice_unprocessed,
}

/* WASAPI audio thread priority characteristics. */
wasapi_usage :: enum u32 {
	wasapi_usage_default,
	wasapi_usage_games,
	wasapi_usage_pro_audio,
}

/* AAudio usage types. */
aaudio_usage :: enum u32 {
	/* Leaves the usage type unset. */
	aaudio_usage_default,
	/* AAUDIO_USAGE_MEDIA */
	aaudio_usage_media,
	/* AAUDIO_USAGE_VOICE_COMMUNICATION */
	aaudio_usage_voice_communication,
	/* AAUDIO_USAGE_VOICE_COMMUNICATION_SIGNALLING */
	aaudio_usage_voice_communication_signalling,
	/* AAUDIO_USAGE_ALARM */
	aaudio_usage_alarm,
	/* AAUDIO_USAGE_NOTIFICATION */
	aaudio_usage_notification,
	/* AAUDIO_USAGE_NOTIFICATION_RINGTONE */
	aaudio_usage_notification_ringtone,
	/* AAUDIO_USAGE_NOTIFICATION_EVENT */
	aaudio_usage_notification_event,
	/* AAUDIO_USAGE_ASSISTANCE_ACCESSIBILITY */
	aaudio_usage_assistance_accessibility,
	/* AAUDIO_USAGE_ASSISTANCE_NAVIGATION_GUIDANCE */
	aaudio_usage_assistance_navigation_guidance,
	/* AAUDIO_USAGE_ASSISTANCE_SONIFICATION */
	aaudio_usage_assistance_sonification,
	/* AAUDIO_USAGE_GAME */
	aaudio_usage_game,
	/* AAUDIO_USAGE_ASSISTANT */
	aaudio_usage_assitant,
	/* AAUDIO_SYSTEM_USAGE_EMERGENCY */
	aaudio_usage_emergency,
	/* AAUDIO_SYSTEM_USAGE_SAFETY */
	aaudio_usage_safety,
	/* AAUDIO_SYSTEM_USAGE_VEHICLE_STATUS */
	aaudio_usage_vehicle_status,
	/* AAUDIO_SYSTEM_USAGE_ANNOUNCEMENT */
	aaudio_usage_announcement,
}

/* AAudio content types. */
aaudio_content_type :: enum u32 {
	/* Leaves the content type unset. */
	aaudio_content_type_default,
	/* AAUDIO_CONTENT_TYPE_SPEECH */
	aaudio_content_type_speech,
	/* AAUDIO_CONTENT_TYPE_MUSIC */
	aaudio_content_type_music,
	/* AAUDIO_CONTENT_TYPE_MOVIE */
	aaudio_content_type_movie,
	/* AAUDIO_CONTENT_TYPE_SONIFICATION */
	aaudio_content_type_sonification,
}

/* AAudio input presets. */
aaudio_input_preset :: enum u32 {
	/* Leaves the input preset unset. */
	aaudio_input_preset_default,
	/* AAUDIO_INPUT_PRESET_GENERIC */
	aaudio_input_preset_generic,
	/* AAUDIO_INPUT_PRESET_CAMCORDER */
	aaudio_input_preset_camcorder,
	/* AAUDIO_INPUT_PRESET_VOICE_RECOGNITION */
	aaudio_input_preset_voice_recognition,
	/* AAUDIO_INPUT_PRESET_VOICE_COMMUNICATION */
	aaudio_input_preset_voice_communication,
	/* AAUDIO_INPUT_PRESET_UNPROCESSED */
	aaudio_input_preset_unprocessed,
	/* AAUDIO_INPUT_PRESET_VOICE_PERFORMANCE */
	aaudio_input_preset_voice_performance,
}

aaudio_allowed_capture_policy :: enum u32 {
	/* Leaves the allowed capture policy unset. */
	aaudio_allow_capture_default,
	/* AAUDIO_ALLOW_CAPTURE_BY_ALL */
	aaudio_allow_capture_by_all,
	/* AAUDIO_ALLOW_CAPTURE_BY_SYSTEM */
	aaudio_allow_capture_by_system,
	/* AAUDIO_ALLOW_CAPTURE_BY_NONE */
	aaudio_allow_capture_by_none,
}

timer :: struct #raw_union {
	counter:  int64,
	counterD: f64,
}

device_id :: struct #raw_union {
	/* WASAPI uses a wchar_t string for identification. */
	wasapi:      [64]wchar_win32,
	/* DirectSound uses a GUID for identification. */
	dsound:      [16]uint8,
	/* When creating a device, WinMM expects a Win32 UINT_PTR for device identification. In practice it's actually just a UINT. */
	winmm:       uint32,
	/* ALSA uses a name string for identification. */
	alsa:        [256]u8,
	/* PulseAudio uses a name string for identification. */
	pulse:       [256]u8,
	/* JACK always uses default devices. */
	jack:        i32,
	/* Core Audio uses a string for identification. */
	coreaudio:   [256]u8,
	/* "snd/0", etc. */
	sndio:       [256]u8,
	/* "/dev/audio", etc. */
	audio4:      [256]u8,
	/* "dev/dsp0", etc. "dev/dsp" for the default device. */
	oss:         [64]u8,
	/* AAudio uses a 32-bit integer for identification. */
	aaudio:      int32,
	/* OpenSL|ES uses a 32-bit unsigned integer for identification. */
	opensl:      uint32,
	/* Web Audio always uses default devices for now, but if this changes it'll be a GUID. */
	webaudio:    [32]u8,
	/* The custom backend could be anything. Give them a few options. */
	custom:      struct #raw_union {
		i: i32,
		s: [256]u8,
		p: rawptr,
	},
	/* The null backend uses an integer for device IDs. */
	nullbackend: i32,
}

context_config :: struct {
	pLog:                ^log,
	threadPriority:      thread_priority,
	threadStackSize:     uint,
	pUserData:           rawptr,
	allocationCallbacks: allocation_callbacks,
	dsound:              struct {
		/* HWND. Optional window handle to pass into SetCooperativeLevel(). Will default to the foreground window, and if that fails, the desktop window. */
		hWnd: handle,
	},
	alsa:                struct {
		useVerboseDeviceEnumeration: bool32,
	},
	pulse:               struct {
		pApplicationName: cstring,
		pServerName:      cstring,
		/* Enables autospawning of the PulseAudio daemon if necessary. */
		tryAutoSpawn:     bool32,
	},
	coreaudio:           struct {
		sessionCategory:          ios_session_category,
		sessionCategoryOptions:   uint32,
		/* iOS only. When set to true, does not perform an explicit [[AVAudioSession sharedInstace] setActive:true] on initialization. */
		noAudioSessionActivate:   bool32,
		/* iOS only. When set to true, does not perform an explicit [[AVAudioSession sharedInstace] setActive:false] on uninitialization. */
		noAudioSessionDeactivate: bool32,
	},
	jack:                struct {
		pClientName:    cstring,
		tryStartServer: bool32,
	},
	custom:              backend_callbacks,
}

device_config :: struct {
	deviceType:                device_type,
	sampleRate:                uint32,
	periodSizeInFrames:        uint32,
	periodSizeInMilliseconds:  uint32,
	periods:                   uint32,
	performanceProfile:        performance_profile,
	/* When set to true, the contents of the output buffer passed into the data callback will be left undefined rather than initialized to silence. */
	noPreSilencedOutputBuffer: bool8,
	/* When set to true, the contents of the output buffer passed into the data callback will not be clipped after returning. Only applies when the playback sample format is f32. */
	noClip:                    bool8,
	/* Do not disable denormals when firing the data callback. */
	noDisableDenormals:        bool8,
	/* Disables strict fixed-sized data callbacks. Setting this to true will result in the period size being treated only as a hint to the backend. This is an optimization for those who don't need fixed sized callbacks. */
	noFixedSizedCallback:      bool8,
	dataCallback:              device_data_proc,
	notificationCallback:      device_notification_proc,
	stopCallback:              stop_proc,
	pUserData:                 rawptr,
	resampling:                resampler_config,
	playback:                  struct {
		pDeviceID:                       ^device_id,
		format:                          format,
		channels:                        uint32,
		pChannelMap:                     ^channel,
		channelMixMode:                  channel_mix_mode,
		/* When an output LFE channel is present, but no input LFE, set to true to set the output LFE to the average of all spatial channels (LR, FR, etc.). Ignored when an input LFE is present. */
		calculateLFEFromSpatialChannels: bool32,
		shareMode:                       share_mode,
	},
	capture:                   struct {
		pDeviceID:                       ^device_id,
		format:                          format,
		channels:                        uint32,
		pChannelMap:                     ^channel,
		channelMixMode:                  channel_mix_mode,
		/* When an output LFE channel is present, but no input LFE, set to true to set the output LFE to the average of all spatial channels (LR, FR, etc.). Ignored when an input LFE is present. */
		calculateLFEFromSpatialChannels: bool32,
		shareMode:                       share_mode,
	},
	wasapi:                    struct {
		/* When configured, uses Avrt APIs to set the thread characteristics. */
		usage:                  wasapi_usage,
		/* When set to true, disables the use of AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM. */
		noAutoConvertSRC:       bool8,
		/* When set to true, disables the use of AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY. */
		noDefaultQualitySRC:    bool8,
		/* Disables automatic stream routing. */
		noAutoStreamRouting:    bool8,
		/* Disables WASAPI's hardware offloading feature. */
		noHardwareOffloading:   bool8,
		/* The process ID to include or exclude for loopback mode. Set to 0 to capture audio from all processes. Ignored when an explicit device ID is specified. */
		loopbackProcessID:      uint32,
		/* When set to true, excludes the process specified by loopbackProcessID. By default, the process will be included. */
		loopbackProcessExclude: bool8,
	},
	alsa:                      struct {
		/* Disables MMap mode. */
		noMMap:         bool32,
		/* Opens the ALSA device with SND_PCM_NO_AUTO_FORMAT. */
		noAutoFormat:   bool32,
		/* Opens the ALSA device with SND_PCM_NO_AUTO_CHANNELS. */
		noAutoChannels: bool32,
		/* Opens the ALSA device with SND_PCM_NO_AUTO_RESAMPLE. */
		noAutoResample: bool32,
	},
	pulse:                     struct {
		pStreamNamePlayback: cstring,
		pStreamNameCapture:  cstring,
		channelMap:          i32,
	},
	coreaudio:                 struct {
		/* Desktop only. When enabled, allows changing of the sample rate at the operating system level. */
		allowNominalSampleRateChange: bool32,
	},
	opensl:                    struct {
		streamType:                     opensl_stream_type,
		recordingPreset:                opensl_recording_preset,
		enableCompatibilityWorkarounds: bool32,
	},
	aaudio:                    struct {
		usage:                          aaudio_usage,
		contentType:                    aaudio_content_type,
		inputPreset:                    aaudio_input_preset,
		allowedCapturePolicy:           aaudio_allowed_capture_policy,
		noAutoStartAfterReroute:        bool32,
		enableCompatibilityWorkarounds: bool32,
		allowSetBufferCapacity:         bool32,
	},
}

/*
These are the callbacks required to be implemented for a backend. These callbacks are grouped into two parts: context and device. There is one context
to many devices. A device is created from a context.

The general flow goes like this:

  1) A context is created with `onContextInit()`
     1a) Available devices can be enumerated with `onContextEnumerateDevices()` if required.
     1b) Detailed information about a device can be queried with `onContextGetDeviceInfo()` if required.
  2) A device is created from the context that was created in the first step using `onDeviceInit()`, and optionally a device ID that was
     selected from device enumeration via `onContextEnumerateDevices()`.
  3) A device is started or stopped with `onDeviceStart()` / `onDeviceStop()`
  4) Data is delivered to and from the device by the backend. This is always done based on the native format returned by the prior call
     to `onDeviceInit()`. Conversion between the device's native format and the format requested by the application will be handled by
     miniaudio internally.

Initialization of the context is quite simple. You need to do any necessary initialization of internal objects and then output the
callbacks defined in this structure.

Once the context has been initialized you can initialize a device. Before doing so, however, the application may want to know which
physical devices are available. This is where `onContextEnumerateDevices()` comes in. This is fairly simple. For each device, fire the
given callback with, at a minimum, the basic information filled out in `ma_device_info`. When the callback returns `MA_FALSE`, enumeration
needs to stop and the `onContextEnumerateDevices()` function returns with a success code.

Detailed device information can be retrieved from a device ID using `onContextGetDeviceInfo()`. This takes as input the device type and ID,
and on output returns detailed information about the device in `ma_device_info`. The `onContextGetDeviceInfo()` callback must handle the
case when the device ID is NULL, in which case information about the default device needs to be retrieved.

Once the context has been created and the device ID retrieved (if using anything other than the default device), the device can be created.
This is a little bit more complicated than initialization of the context due to its more complicated configuration. When initializing a
device, a duplex device may be requested. This means a separate data format needs to be specified for both playback and capture. On input,
the data format is set to what the application wants. On output it's set to the native format which should match as closely as possible to
the requested format. The conversion between the format requested by the application and the device's native format will be handled
internally by miniaudio.

On input, if the sample format is set to `ma_format_unknown`, the backend is free to use whatever sample format it desires, so long as it's
supported by miniaudio. When the channel count is set to 0, the backend should use the device's native channel count. The same applies for
sample rate. For the channel map, the default should be used when `ma_channel_map_is_blank()` returns true (all channels set to
`MA_CHANNEL_NONE`). On input, the `periodSizeInFrames` or `periodSizeInMilliseconds` option should always be set. The backend should
inspect both of these variables. If `periodSizeInFrames` is set, it should take priority, otherwise it needs to be derived from the period
size in milliseconds (`periodSizeInMilliseconds`) and the sample rate, keeping in mind that the sample rate may be 0, in which case the
sample rate will need to be determined before calculating the period size in frames. On output, all members of the `ma_device_descriptor`
object should be set to a valid value, except for `periodSizeInMilliseconds` which is optional (`periodSizeInFrames` *must* be set).

Starting and stopping of the device is done with `onDeviceStart()` and `onDeviceStop()` and should be self-explanatory. If the backend uses
asynchronous reading and writing, `onDeviceStart()` and `onDeviceStop()` should always be implemented.

The handling of data delivery between the application and the device is the most complicated part of the process. To make this a bit
easier, some helper callbacks are available. If the backend uses a blocking read/write style of API, the `onDeviceRead()` and
`onDeviceWrite()` callbacks can optionally be implemented. These are blocking and work just like reading and writing from a file. If the
backend uses a callback for data delivery, that callback must call `ma_device_handle_backend_data_callback()` from within its callback.
This allows miniaudio to then process any necessary data conversion and then pass it to the miniaudio data callback.

If the backend requires absolute flexibility with its data delivery, it can optionally implement the `onDeviceDataLoop()` callback
which will allow it to implement the logic that will run on the audio thread. This is much more advanced and is completely optional.

The audio thread should run data delivery logic in a loop while `ma_device_get_state() == ma_device_state_started` and no errors have been
encountered. Do not start or stop the device here. That will be handled from outside the `onDeviceDataLoop()` callback.

The invocation of the `onDeviceDataLoop()` callback will be handled by miniaudio. When you start the device, miniaudio will fire this
callback. When the device is stopped, the `ma_device_get_state() == ma_device_state_started` condition will fail and the loop will be terminated
which will then fall through to the part that stops the device. For an example on how to implement the `onDeviceDataLoop()` callback,
look at `ma_device_audio_thread__default_read_write()`. Implement the `onDeviceDataLoopWakeup()` callback if you need a mechanism to
wake up the audio thread.

If the backend supports an optimized retrieval of device information from an initialized `ma_device` object, it should implement the
`onDeviceGetInfo()` callback. This is optional, in which case it will fall back to `onContextGetDeviceInfo()` which is less efficient.
*/
backend_callbacks :: struct {
	onContextInit:             proc "c" (_: ^context_, _: ^context_config, _: ^backend_callbacks) -> result,
	onContextUninit:           proc "c" (_: ^context_) -> result,
	onContextEnumerateDevices: proc "c" (_: ^context_, _: enum_devices_callback_proc, _: rawptr) -> result,
	onContextGetDeviceInfo:    proc "c" (_: ^context_, _: device_type, _: ^device_id, _: ^device_info) -> result,
	onDeviceInit:              proc "c" (_: ^device, _: ^device_config, _: ^device_descriptor, _: ^device_descriptor) -> result,
	onDeviceUninit:            proc "c" (_: ^device) -> result,
	onDeviceStart:             proc "c" (_: ^device) -> result,
	onDeviceStop:              proc "c" (_: ^device) -> result,
	onDeviceRead:              proc "c" (_: ^device, _: rawptr, _: uint32, _: ^uint32) -> result,
	onDeviceWrite:             proc "c" (_: ^device, _: rawptr, _: uint32, _: ^uint32) -> result,
	onDeviceDataLoop:          proc "c" (_: ^device) -> result,
	onDeviceDataLoopWakeup:    proc "c" (_: ^device) -> result,
	onDeviceGetInfo:           proc "c" (_: ^device, _: device_type, _: ^device_info) -> result,
}

device_info :: struct {
	/* Basic info. This is the only information guaranteed to be filled in during device enumeration. */
	id:                    device_id,
	/* +1 for null terminator. */
	name:                  [256]u8,
	isDefault:             bool32,
	nativeDataFormatCount: uint32,
	/*ma_format_count * ma_standard_sample_rate_count * MA_MAX_CHANNELS*/
	nativeDataFormats:     [64]struct {
		/* Sample format. If set to ma_format_unknown, all sample formats are supported. */
		format:     format,
		/* If set to 0, all channels are supported. */
		channels:   uint32,
		/* If set to 0, all sample rates are supported. */
		sampleRate: uint32,
		/* A combination of MA_DATA_FORMAT_FLAG_* flags. */
		flags:      uint32,
	},
}

/*
The callback for handling device enumeration. This is fired from `ma_context_enumerate_devices()`.


Parameters
----------
pContext (in)
    A pointer to the context performing the enumeration.

deviceType (in)
    The type of the device being enumerated. This will always be either `ma_device_type_playback` or `ma_device_type_capture`.

pInfo (in)
    A pointer to a `ma_device_info` containing the ID and name of the enumerated device. Note that this will not include detailed information about the device,
    only basic information (ID and name). The reason for this is that it would otherwise require opening the backend device to probe for the information which
    is too inefficient.

pUserData (in)
    The user data pointer passed into `ma_context_enumerate_devices()`.
*/
enum_devices_callback_proc :: proc "c" (_: ^context_, _: device_type, _: ^device_info, _: rawptr) -> bool32

/*
Describes some basic details about a playback or capture device.
*/
device_descriptor :: struct {
	pDeviceID:                ^device_id,
	shareMode:                share_mode,
	format:                   format,
	channels:                 uint32,
	sampleRate:               uint32,
	channelMap:               [254]channel,
	periodSizeInFrames:       uint32,
	periodSizeInMilliseconds: uint32,
	periodCount:              uint32,
}

/* WASAPI specific structure for some commands which must run on a common thread due to bugs in WASAPI. */
context_command__wasapi :: struct {
	code:   i32,
	/* This will be signalled when the event is complete. */
	pEvent: ^event,
	data:   struct #raw_union {
		quit:               struct {
			_unused: i32,
		},
		createAudioClient:  struct {
			deviceType:           device_type,
			pAudioClient:         rawptr,
			ppAudioClientService: ^rawptr,
			/* The result from creating the audio client service. */
			pResult:              ^result,
		},
		releaseAudioClient: struct {
			pDevice:    ^device,
			deviceType: device_type,
		},
	},
}

vfs_file :: handle

open_mode_flags :: enum u32 {
	MA_OPEN_MODE_READ = 1,
	MA_OPEN_MODE_WRITE,
}

seek_origin :: enum u32 {
	seek_origin_start,
	seek_origin_current,
	/* Not used by decoders. */
	seek_origin_end,
}

file_info :: struct {
	sizeInBytes: uint64,
}

vfs_callbacks :: struct {
	onOpen:  proc "c" (_: ^ma_vfs, _: cstring, _: uint32, _: ^vfs_file) -> result,
	onOpenW: proc "c" (_: ^ma_vfs, _: ^i32, _: uint32, _: ^vfs_file) -> result,
	onClose: proc "c" (_: ^ma_vfs, _: vfs_file) -> result,
	onRead:  proc "c" (_: ^ma_vfs, _: vfs_file, _: rawptr, _: uint, _: ^uint) -> result,
	onWrite: proc "c" (_: ^ma_vfs, _: vfs_file, _: rawptr, _: uint, _: ^uint) -> result,
	onSeek:  proc "c" (_: ^ma_vfs, _: vfs_file, _: int64, _: seek_origin) -> result,
	onTell:  proc "c" (_: ^ma_vfs, _: vfs_file, _: ^int64) -> result,
	onInfo:  proc "c" (_: ^ma_vfs, _: vfs_file, _: ^file_info) -> result,
}

default_vfs :: struct {
	cb:                  vfs_callbacks,
	/* Only used for the wchar_t version of open() on non-Windows platforms. */
	allocationCallbacks: allocation_callbacks,
}

read_proc :: proc "c" (_: rawptr, _: rawptr, _: uint, _: ^uint) -> result

seek_proc :: proc "c" (_: rawptr, _: int64, _: seek_origin) -> result

tell_proc :: proc "c" (_: rawptr, _: ^int64) -> result

encoding_format :: enum u32 {
	encoding_format_unknown,
	encoding_format_wav,
	encoding_format_flac,
	encoding_format_mp3,
	encoding_format_vorbis,
}

decoder :: struct {
	ds:                     data_source_base,
	/* The decoding backend we'll be pulling data from. */
	pBackend:               ^ma_data_source,
	/* The vtable for the decoding backend. This needs to be stored so we can access the onUninit() callback. */
	pBackendVTable:         ^decoding_backend_vtable,
	pBackendUserData:       rawptr,
	onRead:                 decoder_read_proc,
	onSeek:                 decoder_seek_proc,
	onTell:                 decoder_tell_proc,
	pUserData:              rawptr,
	/* In output sample rate. Used for keeping track of how many frames are available for decoding. */
	readPointerInPCMFrames: uint64,
	outputFormat:           format,
	outputChannels:         uint32,
	outputSampleRate:       uint32,
	/* Data conversion is achieved by running frames through this. */
	converter:              data_converter,
	/* In input format. Can be null if it's not needed. */
	pInputCache:            rawptr,
	/* The capacity of the input cache. */
	inputCacheCap:          uint64,
	/* The number of frames that have been consumed in the cache. Used for determining the next valid frame. */
	inputCacheConsumed:     uint64,
	/* The number of valid frames remaining in the cache. */
	inputCacheRemaining:    uint64,
	allocationCallbacks:    allocation_callbacks,
	data:                   struct #raw_union {
		vfs:    struct {
			pVFS: ^ma_vfs,
			file: vfs_file,
		},
		/* Only used for decoders that were opened against a block of memory. */
		memory: struct {
			pData:          ^uint8,
			dataSize:       uint,
			currentReadPos: uint,
		},
	},
}

decoding_backend_config :: struct {
	preferredFormat: format,
	/* Set to > 0 to generate a seektable if the decoding backend supports it. */
	seekPointCount:  uint32,
}

decoding_backend_vtable :: struct {
	onInit:       proc "c" (
		_: rawptr,
		_: read_proc,
		_: seek_proc,
		_: tell_proc,
		_: rawptr,
		_: ^decoding_backend_config,
		_: ^allocation_callbacks,
		_: ^^ma_data_source,
	) -> result,
	/* Optional. */
	onInitFile:   proc "c" (_: rawptr, _: cstring, _: ^decoding_backend_config, _: ^allocation_callbacks, _: ^^ma_data_source) -> result,
	/* Optional. */
	onInitFileW:  proc "c" (_: rawptr, _: ^i32, _: ^decoding_backend_config, _: ^allocation_callbacks, _: ^^ma_data_source) -> result,
	/* Optional. */
	onInitMemory: proc "c" (_: rawptr, _: rawptr, _: uint, _: ^decoding_backend_config, _: ^allocation_callbacks, _: ^^ma_data_source) -> result,
	onUninit:     proc "c" (_: rawptr, _: ^ma_data_source, _: ^allocation_callbacks),
}

decoder_read_proc :: proc "c" (_: ^decoder, _: rawptr, _: uint, _: ^uint) -> result

decoder_seek_proc :: proc "c" (_: ^decoder, _: int64, _: seek_origin) -> result

decoder_tell_proc :: proc "c" (_: ^decoder, _: ^int64) -> result

decoder_config :: struct {
	/* Set to 0 or ma_format_unknown to use the stream's internal format. */
	format:                 format,
	/* Set to 0 to use the stream's internal channels. */
	channels:               uint32,
	/* Set to 0 to use the stream's internal sample rate. */
	sampleRate:             uint32,
	pChannelMap:            ^channel,
	channelMixMode:         channel_mix_mode,
	ditherMode:             dither_mode,
	resampling:             resampler_config,
	allocationCallbacks:    allocation_callbacks,
	encodingFormat:         encoding_format,
	/* When set to > 0, specifies the number of seek points to use for the generation of a seek table. Not all decoding backends support this. */
	seekPointCount:         uint32,
	ppCustomBackendVTables: ^^decoding_backend_vtable,
	customBackendCount:     uint32,
	pCustomBackendUserData: rawptr,
}

encoder :: struct {
	config:           encoder_config,
	onWrite:          encoder_write_proc,
	onSeek:           encoder_seek_proc,
	onInit:           encoder_init_proc,
	onUninit:         encoder_uninit_proc,
	onWritePCMFrames: encoder_write_pcm_frames_proc,
	pUserData:        rawptr,
	pInternalEncoder: rawptr,
	data:             struct #raw_union {
		vfs: struct {
			pVFS: ^ma_vfs,
			file: vfs_file,
		},
	},
}

encoder_write_proc :: proc "c" (_: ^encoder, _: rawptr, _: uint, _: ^uint) -> result

encoder_seek_proc :: proc "c" (_: ^encoder, _: int64, _: seek_origin) -> result

encoder_init_proc :: proc "c" (_: ^encoder) -> result

encoder_uninit_proc :: proc "c" (_: ^encoder)

encoder_write_pcm_frames_proc :: proc "c" (_: ^encoder, _: rawptr, _: uint64, _: ^uint64) -> result

encoder_config :: struct {
	encodingFormat:      encoding_format,
	format:              format,
	channels:            uint32,
	sampleRate:          uint32,
	allocationCallbacks: allocation_callbacks,
}

waveform_type :: enum u32 {
	waveform_type_sine,
	waveform_type_square,
	waveform_type_triangle,
	waveform_type_sawtooth,
}

waveform_config :: struct {
	format:     format,
	channels:   uint32,
	sampleRate: uint32,
	type:       waveform_type,
	amplitude:  f64,
	frequency:  f64,
}

waveform :: struct {
	ds:      data_source_base,
	config:  waveform_config,
	advance: f64,
	time:    f64,
}

pulsewave_config :: struct {
	format:     format,
	channels:   uint32,
	sampleRate: uint32,
	dutyCycle:  f64,
	amplitude:  f64,
	frequency:  f64,
}

pulsewave :: struct {
	waveform: waveform,
	config:   pulsewave_config,
}

noise_type :: enum u32 {
	noise_type_white,
	noise_type_pink,
	noise_type_brownian,
}

noise_config :: struct {
	format:            format,
	channels:          uint32,
	type:              noise_type,
	seed:              int32,
	amplitude:         f64,
	duplicateChannels: bool32,
}

noise :: struct {
	ds:        data_source_base,
	config:    noise_config,
	lcg:       lcg,
	state:     struct #raw_union {
		pink:     struct {
			bin:          ^^f64,
			accumulation: ^f64,
			counter:      ^uint32,
		},
		brownian: struct {
			accumulation: ^f64,
		},
	},
	/* Memory management. */
	_pHeap:    rawptr,
	_ownsHeap: bool32,
}

resource_manager :: struct {
	config:              resource_manager_config,
	/* The root buffer in the binary tree. */
	pRootDataBufferNode: ^resource_manager_data_buffer_node,
	/* For synchronizing access to the data buffer binary tree. */
	dataBufferBSTLock:   mutex,
	/* The threads for executing jobs. */
	jobThreads:          [64]thread,
	/* Multi-consumer, multi-producer job queue for managing jobs for asynchronous decoding and streaming. */
	jobQueue:            job_queue,
	/* Only used if a custom VFS is not specified. */
	defaultVFS:          default_vfs,
	/* Only used if no log was specified in the config. */
	log:                 log,
}

resource_manager_data_buffer_node :: struct {
	/* The hashed name. This is the key. */
	hashedName32:                 uint32,
	refCount:                     uint32,
	/* Result from asynchronous loading. When loading set to MA_BUSY. When fully loaded set to MA_SUCCESS. When deleting set to MA_UNAVAILABLE. */
	result:                       result,
	/* For allocating execution orders for jobs. */
	executionCounter:             uint32,
	/* For managing the order of execution for asynchronous jobs relating to this object. Incremented as jobs complete processing. */
	executionPointer:             uint32,
	/* Set to true when the underlying data buffer was allocated the resource manager. Set to false if it is owned by the application (via ma_resource_manager_register_*()). */
	isDataOwnedByResourceManager: bool32,
	data:                         resource_manager_data_supply,
	pParent:                      ^resource_manager_data_buffer_node,
	pChildLo:                     ^resource_manager_data_buffer_node,
	pChildHi:                     ^resource_manager_data_buffer_node,
}

resource_manager_data_buffer :: struct {
	/* Base data source. A data buffer is a data source. */
	ds:                     data_source_base,
	/* A pointer to the resource manager that owns this buffer. */
	pResourceManager:       ^resource_manager,
	/* The data node. This is reference counted and is what supplies the data. */
	pNode:                  ^resource_manager_data_buffer_node,
	/* The flags that were passed used to initialize the buffer. */
	flags:                  uint32,
	/* For allocating execution orders for jobs. */
	executionCounter:       uint32,
	/* For managing the order of execution for asynchronous jobs relating to this object. Incremented as jobs complete processing. */
	executionPointer:       uint32,
	/* Only updated by the public API. Never written nor read from the job thread. */
	seekTargetInPCMFrames:  uint64,
	/* On the next read we need to seek to the frame cursor. */
	seekToCursorOnNextRead: bool32,
	/* Keeps track of a result of decoding. Set to MA_BUSY while the buffer is still loading. Set to MA_SUCCESS when loading is finished successfully. Otherwise set to some other code. */
	result:                 result,
	/* Can be read and written by different threads at the same time. Must be used atomically. */
	isLooping:              bool32,
	/* Used for asynchronous loading to ensure we don't try to initialize the connector multiple times while waiting for the node to fully load. */
	isConnectorInitialized: atomic_bool32,
	/* Connects this object to the node's data supply. */
	connector:              struct #raw_union {
		/* Supply type is ma_resource_manager_data_supply_type_encoded */
		decoder:     decoder,
		/* Supply type is ma_resource_manager_data_supply_type_decoded */
		buffer:      audio_buffer,
		/* Supply type is ma_resource_manager_data_supply_type_decoded_paged */
		pagedBuffer: paged_audio_buffer,
	},
}

resource_manager_data_stream :: struct {
	/* Base data source. A data stream is a data source. */
	ds:                     data_source_base,
	/* A pointer to the resource manager that owns this data stream. */
	pResourceManager:       ^resource_manager,
	/* The flags that were passed used to initialize the stream. */
	flags:                  uint32,
	/* Used for filling pages with data. This is only ever accessed by the job thread. The public API should never touch this. */
	decoder:                decoder,
	/* Required for determining whether or not the decoder should be uninitialized in MA_JOB_TYPE_RESOURCE_MANAGER_FREE_DATA_STREAM. */
	isDecoderInitialized:   bool32,
	/* This is calculated when first loaded by the MA_JOB_TYPE_RESOURCE_MANAGER_LOAD_DATA_STREAM. */
	totalLengthInPCMFrames: uint64,
	/* The playback cursor, relative to the current page. Only ever accessed by the public API. Never accessed by the job thread. */
	relativeCursor:         uint32,
	/* The playback cursor, in absolute position starting from the start of the file. */
	absoluteCursor:         uint64,
	/* Toggles between 0 and 1. Index 0 is the first half of pPageData. Index 1 is the second half. Only ever accessed by the public API. Never accessed by the job thread. */
	currentPageIndex:       uint32,
	/* For allocating execution orders for jobs. */
	executionCounter:       uint32,
	/* For managing the order of execution for asynchronous jobs relating to this object. Incremented as jobs complete processing. */
	executionPointer:       uint32,
	/* Whether or not the stream is looping. It's important to set the looping flag at the data stream level for smooth loop transitions. */
	isLooping:              bool32,
	/* Buffer containing the decoded data of each page. Allocated once at initialization time. */
	pPageData:              rawptr,
	/* The number of valid PCM frames in each page. Used to determine the last valid frame. */
	pageFrameCount:         [2]uint32,
	/* Result from asynchronous loading. When loading set to MA_BUSY. When initialized set to MA_SUCCESS. When deleting set to MA_UNAVAILABLE. If an error occurs when loading, set to an error code. */
	result:                 result,
	/* Whether or not the decoder has reached the end. */
	isDecoderAtEnd:         bool32,
	/* Booleans to indicate whether or not a page is valid. Set to false by the public API, set to true by the job thread. Set to false as the pages are consumed, true when they are filled. */
	isPageValid:            [2]bool32,
	/* When 0, no seeking is being performed. When > 0, a seek is being performed and reading should be delayed with MA_BUSY. */
	seekCounter:            bool32,
}

resource_manager_data_source :: struct {
	/* Must be the first item because we need the first item to be the data source callbacks for the buffer or stream. */
	backend:          struct #raw_union {
		buffer: resource_manager_data_buffer,
		stream: resource_manager_data_stream,
	},
	/* The flags that were passed in to ma_resource_manager_data_source_init(). */
	flags:            uint32,
	/* For allocating execution orders for jobs. */
	executionCounter: uint32,
	/* For managing the order of execution for asynchronous jobs relating to this object. Incremented as jobs complete processing. */
	executionPointer: uint32,
}

resource_manager_data_source_flags :: enum u32 {
	/* When set, does not load the entire data source in memory. Disk I/O will happen on job threads. */
	MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_STREAM = 1,
	/* Decode data before storing in memory. When set, decoding is done at the resource manager level rather than the mixing thread. Results in faster mixing, but higher memory usage. */
	MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_DECODE,
	/* When set, the resource manager will load the data source asynchronously. */
	MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_ASYNC = 4,
	/* When set, waits for initialization of the underlying data source before returning from ma_resource_manager_data_source_init(). */
	MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_WAIT_INIT = 8,
	/* Gives the resource manager a hint that the length of the data source is unknown and calling `ma_data_source_get_length_in_pcm_frames()` should be avoided. */
	MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_UNKNOWN_LENGTH = 16,
	/* When set, configures the data source to loop by default. */
	MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_LOOPING = 32,
}

/*
Pipeline notifications used by the resource manager. Made up of both an async notification and a fence, both of which are optional.
*/
resource_manager_pipeline_stage_notification :: struct {
	pNotification: ^ma_async_notification,
	pFence:        ^fence,
}

resource_manager_pipeline_notifications :: struct {
	/* Initialization of the decoder. */
	init: resource_manager_pipeline_stage_notification,
	/* Decoding fully completed. */
	done: resource_manager_pipeline_stage_notification,
}

resource_manager_flags :: enum u32 {
	/* Indicates ma_resource_manager_next_job() should not block. Only valid when the job thread count is 0. */
	MA_RESOURCE_MANAGER_FLAG_NON_BLOCKING = 1,
	/* Disables any kind of multithreading. Implicitly enables MA_RESOURCE_MANAGER_FLAG_NON_BLOCKING. */
	MA_RESOURCE_MANAGER_FLAG_NO_THREADING,
}

resource_manager_data_source_config :: struct {
	pFilePath:                   cstring,
	pFilePathW:                  ^i32,
	pNotifications:              ^resource_manager_pipeline_notifications,
	initialSeekPointInPCMFrames: uint64,
	rangeBegInPCMFrames:         uint64,
	rangeEndInPCMFrames:         uint64,
	loopPointBegInPCMFrames:     uint64,
	loopPointEndInPCMFrames:     uint64,
	flags:                       uint32,
	/* Deprecated. Use the MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_LOOPING flag in `flags` instead. */
	isLooping:                   bool32,
}

resource_manager_data_supply_type :: enum u32 {
	/* Used for determining whether or the data supply has been initialized. */
	resource_manager_data_supply_type_unknown,
	/* Data supply is an encoded buffer. Connector is ma_decoder. */
	resource_manager_data_supply_type_encoded,
	/* Data supply is a decoded buffer. Connector is ma_audio_buffer. */
	resource_manager_data_supply_type_decoded,
	/* Data supply is a linked list of decoded buffers. Connector is ma_paged_audio_buffer. */
	resource_manager_data_supply_type_decoded_paged,
}

resource_manager_data_supply :: struct {
	/* Read and written from different threads so needs to be accessed atomically. */
	type:    resource_manager_data_supply_type,
	backend: struct #raw_union {
		encoded:      struct {
			pData:       rawptr,
			sizeInBytes: uint,
		},
		decoded:      struct {
			pData:             rawptr,
			totalFrameCount:   uint64,
			decodedFrameCount: uint64,
			format:            format,
			channels:          uint32,
			sampleRate:        uint32,
		},
		decodedPaged: struct {
			data:              paged_audio_buffer_data,
			decodedFrameCount: uint64,
			sampleRate:        uint32,
		},
	},
}

resource_manager_config :: struct {
	allocationCallbacks:            allocation_callbacks,
	pLog:                           ^log,
	/* The decoded format to use. Set to ma_format_unknown (default) to use the file's native format. */
	decodedFormat:                  format,
	/* The decoded channel count to use. Set to 0 (default) to use the file's native channel count. */
	decodedChannels:                uint32,
	/* the decoded sample rate to use. Set to 0 (default) to use the file's native sample rate. */
	decodedSampleRate:              uint32,
	/* Set to 0 if you want to self-manage your job threads. Defaults to 1. */
	jobThreadCount:                 uint32,
	jobThreadStackSize:             uint,
	/* The maximum number of jobs that can fit in the queue at a time. Defaults to MA_JOB_TYPE_RESOURCE_MANAGER_QUEUE_CAPACITY. Cannot be zero. */
	jobQueueCapacity:               uint32,
	flags:                          uint32,
	/* Can be NULL in which case defaults will be used. */
	pVFS:                           ^ma_vfs,
	ppCustomDecodingBackendVTables: ^^decoding_backend_vtable,
	customDecodingBackendCount:     uint32,
	pCustomDecodingBackendUserData: rawptr,
	resampling:                     resampler_config,
}

/* For some internal memory management of ma_node_graph. */
stack :: struct {
	offset:      uint,
	sizeInBytes: uint,
	_data:       [1]u8,
}

node_graph :: struct {
	/* The node graph itself is a node so it can be connected as an input to different node graph. This has zero inputs and calls ma_node_graph_read_pcm_frames() to generate it's output. */
	base:                           node_base,
	/* Special node that all nodes eventually connect to. Data is read from this node in ma_node_graph_read_pcm_frames(). */
	endpoint:                       node_base,
	/* This will be allocated when processingSizeInFrames is non-zero. This is needed because ma_node_graph_read_pcm_frames() can be called with a variable number of frames, and we may need to do some buffering in situations where the caller requests a frame count that's not a multiple of processingSizeInFrames. */
	pProcessingCache:               ^f32,
	processingCacheFramesRemaining: uint32,
	processingSizeInFrames:         uint32,
	/* Read and written by multiple threads. */
	isReading:                      bool32,
	/* Modified only by the audio thread. */
	pPreMixStack:                   ^stack,
}

/* Node flags. */
node_flags :: enum u32 {
	MA_NODE_FLAG_PASSTHROUGH = 1,
	MA_NODE_FLAG_CONTINUOUS_PROCESSING,
	MA_NODE_FLAG_ALLOW_NULL_INPUT = 4,
	MA_NODE_FLAG_DIFFERENT_PROCESSING_RATES = 8,
	MA_NODE_FLAG_SILENT_OUTPUT = 16,
}

/* The playback state of a node. Either started or stopped. */
node_state :: enum u32 {
	node_state_started,
	node_state_stopped,
}

node_vtable :: struct {
	/*
	    Extended processing callback. This callback is used for effects that process input and output
	    at different rates (i.e. they perform resampling). This is similar to the simple version, only
	    they take two separate frame counts: one for input, and one for output.
	
	    On input, `pFrameCountOut` is equal to the capacity of the output buffer for each bus, whereas
	    `pFrameCountIn` will be equal to the number of PCM frames in each of the buffers in `ppFramesIn`.
	
	    On output, set `pFrameCountOut` to the number of PCM frames that were actually output and set
	    `pFrameCountIn` to the number of input frames that were consumed.
	    */
	onProcess:                    proc "c" (_: ^ma_node, _: ^^f32, _: ^uint32, _: ^^f32, _: ^uint32),
	/*
	    A callback for retrieving the number of input frames that are required to output the
	    specified number of output frames. You would only want to implement this when the node performs
	    resampling. This is optional, even for nodes that perform resampling, but it does offer a
	    small reduction in latency as it allows miniaudio to calculate the exact number of input frames
	    to read at a time instead of having to estimate.
	    */
	onGetRequiredInputFrameCount: proc "c" (_: ^ma_node, _: uint32, _: ^uint32) -> result,
	/*
	    The number of input buses. This is how many sub-buffers will be contained in the `ppFramesIn`
	    parameters of the callbacks above.
	    */
	inputBusCount:                uint8,
	/*
	    The number of output buses. This is how many sub-buffers will be contained in the `ppFramesOut`
	    parameters of the callbacks above.
	    */
	outputBusCount:               uint8,
	/*
	    Flags describing characteristics of the node. This is currently just a placeholder for some
	    ideas for later on.
	    */
	flags:                        uint32,
}

node_config :: struct {
	/* Should never be null. Initialization of the node will fail if so. */
	vtable:          ^node_vtable,
	/* Defaults to ma_node_state_started. */
	initialState:    node_state,
	/* Only used if the vtable specifies an input bus count of `MA_NODE_BUS_COUNT_UNKNOWN`, otherwise must be set to `MA_NODE_BUS_COUNT_UNKNOWN` (default). */
	inputBusCount:   uint32,
	/* Only used if the vtable specifies an output bus count of `MA_NODE_BUS_COUNT_UNKNOWN`, otherwise  be set to `MA_NODE_BUS_COUNT_UNKNOWN` (default). */
	outputBusCount:  uint32,
	/* The number of elements are determined by the input bus count as determined by the vtable, or `inputBusCount` if the vtable specifies `MA_NODE_BUS_COUNT_UNKNOWN`. */
	pInputChannels:  ^uint32,
	/* The number of elements are determined by the output bus count as determined by the vtable, or `outputBusCount` if the vtable specifies `MA_NODE_BUS_COUNT_UNKNOWN`. */
	pOutputChannels: ^uint32,
}

node_output_bus :: struct {
	/* The node that owns this output bus. The input node. Will be null for dummy head and tail nodes. */
	pNode:                  ^ma_node,
	/* The index of the output bus on pNode that this output bus represents. */
	outputBusIndex:         uint8,
	/* The number of channels in the audio stream for this bus. */
	channels:               uint8,
	/* The index of the input bus on the input. Required for detaching. Will only be used within the spinlock so does not need to be atomic. */
	inputNodeInputBusIndex: uint8,
	/* Some state flags for tracking the read state of the output buffer. A combination of MA_NODE_OUTPUT_BUS_FLAG_*. */
	flags:                  uint32,
	/* Reference count for some thread-safety when detaching. */
	refCount:               uint32,
	/* This is used to prevent iteration of nodes that are in the middle of being detached. Used for thread safety. */
	isAttached:             bool32,
	/* Unfortunate lock, but significantly simplifies the implementation. Required for thread-safe attaching and detaching. */
	lock:                   spinlock,
	/* Linear. */
	volume:                 f32,
	/* If null, it's the tail node or detached. */
	pNext:                  ^node_output_bus,
	/* If null, it's the head node or detached. */
	pPrev:                  ^node_output_bus,
	/* The node that this output bus is attached to. Required for detaching. */
	pInputNode:             ^ma_node,
}

node_input_bus :: struct {
	/* Dummy head node for simplifying some lock-free thread-safety stuff. */
	head:        node_output_bus,
	/* This is used to determine whether or not the input bus is finding the next node in the list. Used for thread safety when detaching output buses. */
	nextCounter: uint32,
	/* Unfortunate lock, but significantly simplifies the implementation. Required for thread-safe attaching and detaching. */
	lock:        spinlock,
	/* The number of channels in the audio stream for this bus. */
	channels:    uint8,
}

node_base :: struct {
	/* The graph this node belongs to. */
	pNodeGraph:                  ^node_graph,
	vtable:                      ^node_vtable,
	inputBusCount:               uint32,
	outputBusCount:              uint32,
	pInputBuses:                 ^node_input_bus,
	pOutputBuses:                ^node_output_bus,
	/* Allocated on the heap. Fixed size. Needs to be stored on the heap because reading from output buses is done in separate function calls. */
	pCachedData:                 ^f32,
	/* The capacity of the input data cache in frames, per bus. */
	cachedDataCapInFramesPerBus: uint16,
	/* These variables are read and written only from the audio thread. */
	cachedFrameCountOut:         uint16,
	cachedFrameCountIn:          uint16,
	consumedFrameCountIn:        uint16,
	/* When set to stopped, nothing will be read, regardless of the times in stateTimes. */
	state:                       node_state,
	/* Indexed by ma_node_state. Specifies the time based on the global clock that a node should be considered to be in the relevant state. */
	stateTimes:                  [2]uint64,
	/* The node's local clock. This is just a running sum of the number of output frames that have been processed. Can be modified by any thread with `ma_node_set_time()`. */
	localTime:                   uint64,
	/* Memory management. */
	_inputBuses:                 [2]node_input_bus,
	_outputBuses:                [2]node_output_bus,
	/* A heap allocation for internal use only. pInputBuses and/or pOutputBuses will point to this if the bus count exceeds MA_MAX_NODE_LOCAL_BUS_COUNT. */
	_pHeap:                      rawptr,
	/* If set to true, the node owns the heap allocation and _pHeap will be freed in ma_node_uninit(). */
	_ownsHeap:                   bool32,
}

node_graph_config :: struct {
	channels:               uint32,
	/* This is the preferred processing size for node processing callbacks unless overridden by a node itself. Can be 0 in which case it will be based on the frame count passed into ma_node_graph_read_pcm_frames(), but will not be well defined. */
	processingSizeInFrames: uint32,
	/* Defaults to 512KB per channel. Reducing this will save memory, but the depth of your node graph will be more restricted. */
	preMixStackSizeInBytes: uint,
}

/* Data source node. 0 input buses, 1 output bus. Used for reading from a data source. */
data_source_node_config :: struct {
	nodeConfig:  node_config,
	pDataSource: ^ma_data_source,
}

data_source_node :: struct {
	base:        node_base,
	pDataSource: ^ma_data_source,
}

/* Splitter Node. 1 input, many outputs. Used for splitting/copying a stream so it can be as input into two separate output nodes. */
splitter_node_config :: struct {
	nodeConfig:     node_config,
	channels:       uint32,
	outputBusCount: uint32,
}

splitter_node :: struct {
	base: node_base,
}

/*
Biquad Node
*/
biquad_node_config :: struct {
	nodeConfig: node_config,
	biquad:     biquad_config,
}

biquad_node :: struct {
	baseNode: node_base,
	biquad:   biquad,
}

/*
Low Pass Filter Node
*/
lpf_node_config :: struct {
	nodeConfig: node_config,
	lpf:        lpf_config,
}

lpf_node :: struct {
	baseNode: node_base,
	lpf:      lpf,
}

/*
High Pass Filter Node
*/
hpf_node_config :: struct {
	nodeConfig: node_config,
	hpf:        hpf_config,
}

hpf_node :: struct {
	baseNode: node_base,
	hpf:      hpf,
}

/*
Band Pass Filter Node
*/
bpf_node_config :: struct {
	nodeConfig: node_config,
	bpf:        bpf_config,
}

bpf_node :: struct {
	baseNode: node_base,
	bpf:      bpf,
}

/*
Notching Filter Node
*/
notch_node_config :: struct {
	nodeConfig: node_config,
	notch:      notch_config,
}

notch_node :: struct {
	baseNode: node_base,
	notch:    notch2,
}

/*
Peaking Filter Node
*/
peak_node_config :: struct {
	nodeConfig: node_config,
	peak:       peak_config,
}

peak_node :: struct {
	baseNode: node_base,
	peak:     peak2,
}

/*
Low Shelf Filter Node
*/
loshelf_node_config :: struct {
	nodeConfig: node_config,
	loshelf:    loshelf_config,
}

loshelf_node :: struct {
	baseNode: node_base,
	loshelf:  loshelf2,
}

/*
High Shelf Filter Node
*/
hishelf_node_config :: struct {
	nodeConfig: node_config,
	hishelf:    hishelf_config,
}

hishelf_node :: struct {
	baseNode: node_base,
	hishelf:  hishelf2,
}

delay_node_config :: struct {
	nodeConfig: node_config,
	delay:      delay_config,
}

delay_node :: struct {
	baseNode: node_base,
	delay:    delay,
}

engine :: struct {
	/* An engine is a node graph. It should be able to be plugged into any ma_node_graph API (with a cast) which means this must be the first member of this struct. */
	nodeGraph:                          node_graph,
	pResourceManager:                   ^resource_manager,
	/* Optionally set via the config, otherwise allocated by the engine in ma_engine_init(). */
	pDevice:                            ^device,
	pLog:                               ^log,
	sampleRate:                         uint32,
	listenerCount:                      uint32,
	listeners:                          [4]spatializer_listener,
	allocationCallbacks:                allocation_callbacks,
	ownsResourceManager:                bool8,
	ownsDevice:                         bool8,
	/* For synchronizing access to the inlined sound list. */
	inlinedSoundLock:                   spinlock,
	/* The first inlined sound. Inlined sounds are tracked in a linked list. */
	pInlinedSoundHead:                  ^sound_inlined,
	/* The total number of allocated inlined sound objects. Used for debugging. */
	inlinedSoundCount:                  uint32,
	/* The number of frames to interpolate the gain of spatialized sounds across. */
	gainSmoothTimeInFrames:             uint32,
	defaultVolumeSmoothTimeInPCMFrames: uint32,
	monoExpansionMode:                  mono_expansion_mode,
	onProcess:                          engine_process_proc,
	pProcessUserData:                   rawptr,
	pitchResamplingConfig:              resampler_config,
}

sound :: struct {
	/* Must be the first member for compatibility with the ma_node API. */
	engineNode:                     engine_node,
	pDataSource:                    ^ma_data_source,
	/* The PCM frame index to seek to in the mixing thread. Set to (~(ma_uint64)0) to not perform any seeking. */
	seekTarget:                     uint64,
	atEnd:                          bool32,
	endCallback:                    sound_end_proc,
	pEndCallbackUserData:           rawptr,
	/* Will be null if pDataSource is null. */
	pProcessingCache:               ^f32,
	processingCacheFramesRemaining: uint32,
	processingCacheCap:             uint32,
	ownsDataSource:                 bool8,
	pResourceManagerDataSource:     ^resource_manager_data_source,
}

/* Sound flags. */
sound_flags :: enum u32 {
	/* MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_STREAM */
	MA_SOUND_FLAG_STREAM = 1,
	/* MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_DECODE */
	MA_SOUND_FLAG_DECODE,
	/* MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_ASYNC */
	MA_SOUND_FLAG_ASYNC = 4,
	/* MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_WAIT_INIT */
	MA_SOUND_FLAG_WAIT_INIT = 8,
	/* MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_UNKNOWN_LENGTH */
	MA_SOUND_FLAG_UNKNOWN_LENGTH = 16,
	/* MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_LOOPING */
	MA_SOUND_FLAG_LOOPING = 32,
	/* Do not attach to the endpoint by default. Useful for when setting up nodes in a complex graph system. */
	MA_SOUND_FLAG_NO_DEFAULT_ATTACHMENT = 4096,
	/* Disable pitch shifting with ma_sound_set_pitch() and ma_sound_group_set_pitch(). This is an optimization. */
	MA_SOUND_FLAG_NO_PITCH = 8192,
	/* Disable spatialization. */
	MA_SOUND_FLAG_NO_SPATIALIZATION = 16384,
}

engine_node_type :: enum u32 {
	engine_node_type_sound,
	engine_node_type_group,
}

engine_node_config :: struct {
	pEngine:                     ^engine,
	type:                        engine_node_type,
	channelsIn:                  uint32,
	channelsOut:                 uint32,
	/* Only used when the type is set to ma_engine_node_type_sound. */
	sampleRate:                  uint32,
	/* The number of frames to smooth over volume changes. Defaults to 0 in which case no smoothing is used. */
	volumeSmoothTimeInPCMFrames: uint32,
	monoExpansionMode:           mono_expansion_mode,
	/* Pitching can be explicitly disabled with MA_SOUND_FLAG_NO_PITCH to optimize processing. */
	isPitchDisabled:             bool8,
	/* Spatialization can be explicitly disabled with MA_SOUND_FLAG_NO_SPATIALIZATION. */
	isSpatializationDisabled:    bool8,
	/* The index of the listener this node should always use for spatialization. If set to MA_LISTENER_INDEX_CLOSEST the engine will use the closest listener. */
	pinnedListenerIndex:         uint8,
	resampling:                  resampler_config,
}

/* Base node object for both ma_sound and ma_sound_group. */
engine_node :: struct {
	/* Must be the first member for compatibility with the ma_node API. */
	baseNode:                    node_base,
	/* A pointer to the engine. Set based on the value from the config. */
	pEngine:                     ^engine,
	/* The sample rate of the input data. For sounds backed by a data source, this will be the data source's sample rate. Otherwise it'll be the engine's sample rate. */
	sampleRate:                  uint32,
	volumeSmoothTimeInPCMFrames: uint32,
	monoExpansionMode:           mono_expansion_mode,
	fader:                       fader,
	/* For pitch shift. */
	resampler:                   resampler,
	spatializer:                 spatializer,
	panner:                      panner,
	/* This will only be used if volumeSmoothTimeInPCMFrames is > 0. */
	volumeGainer:                gainer,
	/* Defaults to 1. */
	volume:                      atomic_float,
	pitch:                       f32,
	/* For determining whether or not the resampler needs to be updated to reflect the new pitch. The resampler will be updated on the mixing thread. */
	oldPitch:                    f32,
	/* For determining whether or not the resampler needs to be updated to take a new doppler pitch into account. */
	oldDopplerPitch:             f32,
	/* When set to true, pitching will be disabled which will allow the resampler to be bypassed to save some computation. */
	isPitchDisabled:             bool32,
	/* Set to false by default. When set to false, will not have spatialisation applied. */
	isSpatializationDisabled:    bool32,
	/* The index of the listener this node should always use for spatialization. If set to MA_LISTENER_INDEX_CLOSEST the engine will use the closest listener. */
	pinnedListenerIndex:         uint32,
	fadeSettings:                struct {
		volumeBeg:                  atomic_float,
		volumeEnd:                  atomic_float,
		/* <-- Defaults to (~(ma_uint64)0) which is used to indicate that no fade should be applied. */
		fadeLengthInFrames:         atomic_uint64,
		/* <-- The time to start the fade. */
		absoluteGlobalTimeInFrames: atomic_uint64,
	},
	/* Memory management. */
	_ownsHeap:                   bool8,
	_pHeap:                      rawptr,
}

/* Callback for when a sound reaches the end. */
sound_end_proc :: proc "c" (_: rawptr, _: ^sound)

sound_config :: struct {
	/* Set this to load from the resource manager. */
	pFilePath:                      cstring,
	/* Set this to load from the resource manager. */
	pFilePathW:                     ^i32,
	/* Set this to load from an existing data source. */
	pDataSource:                    ^ma_data_source,
	/* If set, the sound will be attached to an input of this node. This can be set to a ma_sound. If set to NULL, the sound will be attached directly to the endpoint unless MA_SOUND_FLAG_NO_DEFAULT_ATTACHMENT is set in `flags`. */
	pInitialAttachment:             ^ma_node,
	/* The index of the input bus of pInitialAttachment to attach the sound to. */
	initialAttachmentInputBusIndex: uint32,
	/* Ignored if using a data source as input (the data source's channel count will be used always). Otherwise, setting to 0 will cause the engine's channel count to be used. */
	channelsIn:                     uint32,
	/* Set this to 0 (default) to use the engine's channel count. Set to MA_SOUND_SOURCE_CHANNEL_COUNT to use the data source's channel count (only used if using a data source as input). */
	channelsOut:                    uint32,
	/* Controls how the mono channel should be expanded to other channels when spatialization is disabled on a sound. */
	monoExpansionMode:              mono_expansion_mode,
	/* A combination of MA_SOUND_FLAG_* flags. */
	flags:                          uint32,
	/* The number of frames to smooth over volume changes. Defaults to 0 in which case no smoothing is used. */
	volumeSmoothTimeInPCMFrames:    uint32,
	/* Initializes the sound such that it's seeked to this location by default. */
	initialSeekPointInPCMFrames:    uint64,
	rangeBegInPCMFrames:            uint64,
	rangeEndInPCMFrames:            uint64,
	loopPointBegInPCMFrames:        uint64,
	loopPointEndInPCMFrames:        uint64,
	/* Fired when the sound reaches the end. Will be fired from the audio thread. Do not restart, uninitialize or otherwise change the state of the sound from here. Instead fire an event or set a variable to indicate to a different thread to change the start of the sound. Will not be fired in response to a scheduled stop with ma_sound_set_stop_time_*(). */
	endCallback:                    sound_end_proc,
	pEndCallbackUserData:           rawptr,
	pitchResampling:                resampler_config,
	initNotifications:              resource_manager_pipeline_notifications,
	/* Deprecated. Use initNotifications instead. Released when the resource manager has finished decoding the entire sound. Not used with streams. */
	pDoneFence:                     ^fence,
	/* Deprecated. Use the MA_SOUND_FLAG_LOOPING flag in `flags` instead. */
	isLooping:                      bool32,
}

sound_inlined :: struct {
	sound: sound,
	pNext: ^sound_inlined,
	pPrev: ^sound_inlined,
}

/* A sound group is just a sound. */
sound_group_config :: sound_config

sound_group :: sound

engine_process_proc :: proc "c" (_: rawptr, _: ^f32, _: uint64)

engine_config :: struct {
	/* Can be null in which case a resource manager will be created for you. */
	pResourceManager:                   ^resource_manager,
	pContext:                           ^context_,
	/* If set, the caller is responsible for calling ma_engine_data_callback() in the device's data callback. */
	pDevice:                            ^device,
	/* The ID of the playback device to use with the default listener. */
	pPlaybackDeviceID:                  ^device_id,
	/* Can be null. Can be used to provide a custom device data callback. */
	dataCallback:                       device_data_proc,
	notificationCallback:               device_notification_proc,
	/* When set to NULL, will use the context's log. */
	pLog:                               ^log,
	/* Must be between 1 and MA_ENGINE_MAX_LISTENERS. */
	listenerCount:                      uint32,
	/* The number of channels to use when mixing and spatializing. When set to 0, will use the native channel count of the device. */
	channels:                           uint32,
	/* The sample rate. When set to 0 will use the native sample rate of the device. */
	sampleRate:                         uint32,
	/* If set to something other than 0, updates will always be exactly this size. The underlying device may be a different size, but from the perspective of the mixer that won't matter.*/
	periodSizeInFrames:                 uint32,
	/* Used if periodSizeInFrames is unset. */
	periodSizeInMilliseconds:           uint32,
	/* The number of frames to interpolate the gain of spatialized sounds across. If set to 0, will use gainSmoothTimeInMilliseconds. */
	gainSmoothTimeInFrames:             uint32,
	/* When set to 0, gainSmoothTimeInFrames will be used. If both are set to 0, a default value will be used. */
	gainSmoothTimeInMilliseconds:       uint32,
	/* Defaults to 0. Controls the default amount of smoothing to apply to volume changes to sounds. High values means more smoothing at the expense of high latency (will take longer to reach the new volume). */
	defaultVolumeSmoothTimeInPCMFrames: uint32,
	/* A stack is used for internal processing in the node graph. This allows you to configure the size of this stack. Smaller values will reduce the maximum depth of your node graph. You should rarely need to modify this. */
	preMixStackSizeInBytes:             uint32,
	allocationCallbacks:                allocation_callbacks,
	/* When set to true, requires an explicit call to ma_engine_start(). This is false by default, meaning the engine will be started automatically in ma_engine_init(). */
	noAutoStart:                        bool32,
	/* When set to true, don't create a default device. ma_engine_read_pcm_frames() can be called manually to read data. */
	noDevice:                           bool32,
	/* Controls how the mono channel should be expanded to other channels when spatialization is disabled on a sound. */
	monoExpansionMode:                  mono_expansion_mode,
	/* A pointer to a pre-allocated VFS object to use with the resource manager. This is ignored if pResourceManager is not NULL. */
	pResourceManagerVFS:                ^ma_vfs,
	/* Fired at the end of each call to ma_engine_read_pcm_frames(). For engine's that manage their own internal device (the default configuration), this will be fired from the audio thread, and you do not need to call ma_engine_read_pcm_frames() manually in order to trigger this. */
	onProcess:                          engine_process_proc,
	/* User data that's passed into onProcess. */
	pProcessUserData:                   rawptr,
	/* The resampling config to use with the resource manager. */
	resourceManagerResampling:          resampler_config,
	/* The resampling config for the pitch and Doppler effects. You will typically want this to be a fast resampler. For high quality stuff, it's recommended that you pre-resample. */
	pitchResampling:                    resampler_config,
}

@(link_prefix = "ma_")
foreign lib {
	/*
	Retrieves the version of miniaudio as separated integers. Each component can be NULL if it's not required.
	*/
	version :: proc(pMajor: ^uint32, pMinor: ^uint32, pRevision: ^uint32) ---
	/*
	Retrieves the version of miniaudio as a string which can be useful for logging purposes.
	*/
	version_string :: proc() -> cstring ---
	log_callback_init :: proc(onLog: log_callback_proc, pUserData: rawptr) -> log_callback ---
	log_init :: proc(pAllocationCallbacks: ^allocation_callbacks, pLog: ^log) -> result ---
	log_uninit :: proc(pLog: ^log) ---
	log_register_callback :: proc(pLog: ^log, callback: log_callback) -> result ---
	log_unregister_callback :: proc(pLog: ^log, callback: log_callback) -> result ---
	log_post :: proc(pLog: ^log, level: uint32, pMessage: cstring) -> result ---
	log_postv :: proc(pLog: ^log, level: uint32, pFormat: cstring, args: ^__va_list_tag) -> result ---
	log_postf :: proc(pLog: ^log, level: uint32, pFormat: cstring, #c_vararg _: ..any) -> result ---
	biquad_config_init :: proc(format: format, channels: uint32, b0: f64, b1: f64, b2: f64, a0: f64, a1: f64, a2: f64) -> biquad_config ---
	biquad_get_heap_size :: proc(pConfig: ^biquad_config, pHeapSizeInBytes: ^uint) -> result ---
	biquad_init_preallocated :: proc(pConfig: ^biquad_config, pHeap: rawptr, pBQ: ^biquad) -> result ---
	biquad_init :: proc(pConfig: ^biquad_config, pAllocationCallbacks: ^allocation_callbacks, pBQ: ^biquad) -> result ---
	biquad_uninit :: proc(pBQ: ^biquad, pAllocationCallbacks: ^allocation_callbacks) ---
	biquad_reinit :: proc(pConfig: ^biquad_config, pBQ: ^biquad) -> result ---
	biquad_clear_cache :: proc(pBQ: ^biquad) -> result ---
	biquad_process_pcm_frames :: proc(pBQ: ^biquad, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	biquad_get_latency :: proc(pBQ: ^biquad) -> uint32 ---
	lpf1_config_init :: proc(format: format, channels: uint32, sampleRate: uint32, cutoffFrequency: f64) -> lpf1_config ---
	lpf2_config_init :: proc(format: format, channels: uint32, sampleRate: uint32, cutoffFrequency: f64, q: f64) -> lpf2_config ---
	lpf1_get_heap_size :: proc(pConfig: ^lpf1_config, pHeapSizeInBytes: ^uint) -> result ---
	lpf1_init_preallocated :: proc(pConfig: ^lpf1_config, pHeap: rawptr, pLPF: ^lpf1) -> result ---
	lpf1_init :: proc(pConfig: ^lpf1_config, pAllocationCallbacks: ^allocation_callbacks, pLPF: ^lpf1) -> result ---
	lpf1_uninit :: proc(pLPF: ^lpf1, pAllocationCallbacks: ^allocation_callbacks) ---
	lpf1_reinit :: proc(pConfig: ^lpf1_config, pLPF: ^lpf1) -> result ---
	lpf1_clear_cache :: proc(pLPF: ^lpf1) -> result ---
	lpf1_process_pcm_frames :: proc(pLPF: ^lpf1, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	lpf1_get_latency :: proc(pLPF: ^lpf1) -> uint32 ---
	lpf2_get_heap_size :: proc(pConfig: ^lpf2_config, pHeapSizeInBytes: ^uint) -> result ---
	lpf2_init_preallocated :: proc(pConfig: ^lpf2_config, pHeap: rawptr, pHPF: ^lpf2) -> result ---
	lpf2_init :: proc(pConfig: ^lpf2_config, pAllocationCallbacks: ^allocation_callbacks, pLPF: ^lpf2) -> result ---
	lpf2_uninit :: proc(pLPF: ^lpf2, pAllocationCallbacks: ^allocation_callbacks) ---
	lpf2_reinit :: proc(pConfig: ^lpf2_config, pLPF: ^lpf2) -> result ---
	lpf2_clear_cache :: proc(pLPF: ^lpf2) -> result ---
	lpf2_process_pcm_frames :: proc(pLPF: ^lpf2, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	lpf2_get_latency :: proc(pLPF: ^lpf2) -> uint32 ---
	lpf_config_init :: proc(format: format, channels: uint32, sampleRate: uint32, cutoffFrequency: f64, order: uint32) -> lpf_config ---
	lpf_get_heap_size :: proc(pConfig: ^lpf_config, pHeapSizeInBytes: ^uint) -> result ---
	lpf_init_preallocated :: proc(pConfig: ^lpf_config, pHeap: rawptr, pLPF: ^lpf) -> result ---
	lpf_init :: proc(pConfig: ^lpf_config, pAllocationCallbacks: ^allocation_callbacks, pLPF: ^lpf) -> result ---
	lpf_uninit :: proc(pLPF: ^lpf, pAllocationCallbacks: ^allocation_callbacks) ---
	lpf_reinit :: proc(pConfig: ^lpf_config, pLPF: ^lpf) -> result ---
	lpf_clear_cache :: proc(pLPF: ^lpf) -> result ---
	lpf_process_pcm_frames :: proc(pLPF: ^lpf, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	lpf_get_latency :: proc(pLPF: ^lpf) -> uint32 ---
	hpf1_config_init :: proc(format: format, channels: uint32, sampleRate: uint32, cutoffFrequency: f64) -> hpf1_config ---
	hpf2_config_init :: proc(format: format, channels: uint32, sampleRate: uint32, cutoffFrequency: f64, q: f64) -> hpf2_config ---
	hpf1_get_heap_size :: proc(pConfig: ^hpf1_config, pHeapSizeInBytes: ^uint) -> result ---
	hpf1_init_preallocated :: proc(pConfig: ^hpf1_config, pHeap: rawptr, pLPF: ^hpf1) -> result ---
	hpf1_init :: proc(pConfig: ^hpf1_config, pAllocationCallbacks: ^allocation_callbacks, pHPF: ^hpf1) -> result ---
	hpf1_uninit :: proc(pHPF: ^hpf1, pAllocationCallbacks: ^allocation_callbacks) ---
	hpf1_reinit :: proc(pConfig: ^hpf1_config, pHPF: ^hpf1) -> result ---
	hpf1_process_pcm_frames :: proc(pHPF: ^hpf1, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	hpf1_get_latency :: proc(pHPF: ^hpf1) -> uint32 ---
	hpf2_get_heap_size :: proc(pConfig: ^hpf2_config, pHeapSizeInBytes: ^uint) -> result ---
	hpf2_init_preallocated :: proc(pConfig: ^hpf2_config, pHeap: rawptr, pHPF: ^hpf2) -> result ---
	hpf2_init :: proc(pConfig: ^hpf2_config, pAllocationCallbacks: ^allocation_callbacks, pHPF: ^hpf2) -> result ---
	hpf2_uninit :: proc(pHPF: ^hpf2, pAllocationCallbacks: ^allocation_callbacks) ---
	hpf2_reinit :: proc(pConfig: ^hpf2_config, pHPF: ^hpf2) -> result ---
	hpf2_process_pcm_frames :: proc(pHPF: ^hpf2, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	hpf2_get_latency :: proc(pHPF: ^hpf2) -> uint32 ---
	hpf_config_init :: proc(format: format, channels: uint32, sampleRate: uint32, cutoffFrequency: f64, order: uint32) -> hpf_config ---
	hpf_get_heap_size :: proc(pConfig: ^hpf_config, pHeapSizeInBytes: ^uint) -> result ---
	hpf_init_preallocated :: proc(pConfig: ^hpf_config, pHeap: rawptr, pLPF: ^hpf) -> result ---
	hpf_init :: proc(pConfig: ^hpf_config, pAllocationCallbacks: ^allocation_callbacks, pHPF: ^hpf) -> result ---
	hpf_uninit :: proc(pHPF: ^hpf, pAllocationCallbacks: ^allocation_callbacks) ---
	hpf_reinit :: proc(pConfig: ^hpf_config, pHPF: ^hpf) -> result ---
	hpf_process_pcm_frames :: proc(pHPF: ^hpf, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	hpf_get_latency :: proc(pHPF: ^hpf) -> uint32 ---
	bpf2_config_init :: proc(format: format, channels: uint32, sampleRate: uint32, cutoffFrequency: f64, q: f64) -> bpf2_config ---
	bpf2_get_heap_size :: proc(pConfig: ^bpf2_config, pHeapSizeInBytes: ^uint) -> result ---
	bpf2_init_preallocated :: proc(pConfig: ^bpf2_config, pHeap: rawptr, pBPF: ^bpf2) -> result ---
	bpf2_init :: proc(pConfig: ^bpf2_config, pAllocationCallbacks: ^allocation_callbacks, pBPF: ^bpf2) -> result ---
	bpf2_uninit :: proc(pBPF: ^bpf2, pAllocationCallbacks: ^allocation_callbacks) ---
	bpf2_reinit :: proc(pConfig: ^bpf2_config, pBPF: ^bpf2) -> result ---
	bpf2_process_pcm_frames :: proc(pBPF: ^bpf2, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	bpf2_get_latency :: proc(pBPF: ^bpf2) -> uint32 ---
	bpf_config_init :: proc(format: format, channels: uint32, sampleRate: uint32, cutoffFrequency: f64, order: uint32) -> bpf_config ---
	bpf_get_heap_size :: proc(pConfig: ^bpf_config, pHeapSizeInBytes: ^uint) -> result ---
	bpf_init_preallocated :: proc(pConfig: ^bpf_config, pHeap: rawptr, pBPF: ^bpf) -> result ---
	bpf_init :: proc(pConfig: ^bpf_config, pAllocationCallbacks: ^allocation_callbacks, pBPF: ^bpf) -> result ---
	bpf_uninit :: proc(pBPF: ^bpf, pAllocationCallbacks: ^allocation_callbacks) ---
	bpf_reinit :: proc(pConfig: ^bpf_config, pBPF: ^bpf) -> result ---
	bpf_process_pcm_frames :: proc(pBPF: ^bpf, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	bpf_get_latency :: proc(pBPF: ^bpf) -> uint32 ---
	notch2_config_init :: proc(format: format, channels: uint32, sampleRate: uint32, q: f64, frequency: f64) -> notch2_config ---
	notch2_get_heap_size :: proc(pConfig: ^notch2_config, pHeapSizeInBytes: ^uint) -> result ---
	notch2_init_preallocated :: proc(pConfig: ^notch2_config, pHeap: rawptr, pFilter: ^notch2) -> result ---
	notch2_init :: proc(pConfig: ^notch2_config, pAllocationCallbacks: ^allocation_callbacks, pFilter: ^notch2) -> result ---
	notch2_uninit :: proc(pFilter: ^notch2, pAllocationCallbacks: ^allocation_callbacks) ---
	notch2_reinit :: proc(pConfig: ^notch2_config, pFilter: ^notch2) -> result ---
	notch2_process_pcm_frames :: proc(pFilter: ^notch2, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	notch2_get_latency :: proc(pFilter: ^notch2) -> uint32 ---
	peak2_config_init :: proc(format: format, channels: uint32, sampleRate: uint32, gainDB: f64, q: f64, frequency: f64) -> peak2_config ---
	peak2_get_heap_size :: proc(pConfig: ^peak2_config, pHeapSizeInBytes: ^uint) -> result ---
	peak2_init_preallocated :: proc(pConfig: ^peak2_config, pHeap: rawptr, pFilter: ^peak2) -> result ---
	peak2_init :: proc(pConfig: ^peak2_config, pAllocationCallbacks: ^allocation_callbacks, pFilter: ^peak2) -> result ---
	peak2_uninit :: proc(pFilter: ^peak2, pAllocationCallbacks: ^allocation_callbacks) ---
	peak2_reinit :: proc(pConfig: ^peak2_config, pFilter: ^peak2) -> result ---
	peak2_process_pcm_frames :: proc(pFilter: ^peak2, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	peak2_get_latency :: proc(pFilter: ^peak2) -> uint32 ---
	loshelf2_config_init :: proc(format: format, channels: uint32, sampleRate: uint32, gainDB: f64, shelfSlope: f64, frequency: f64) -> loshelf2_config ---
	loshelf2_get_heap_size :: proc(pConfig: ^loshelf2_config, pHeapSizeInBytes: ^uint) -> result ---
	loshelf2_init_preallocated :: proc(pConfig: ^loshelf2_config, pHeap: rawptr, pFilter: ^loshelf2) -> result ---
	loshelf2_init :: proc(pConfig: ^loshelf2_config, pAllocationCallbacks: ^allocation_callbacks, pFilter: ^loshelf2) -> result ---
	loshelf2_uninit :: proc(pFilter: ^loshelf2, pAllocationCallbacks: ^allocation_callbacks) ---
	loshelf2_reinit :: proc(pConfig: ^loshelf2_config, pFilter: ^loshelf2) -> result ---
	loshelf2_process_pcm_frames :: proc(pFilter: ^loshelf2, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	loshelf2_get_latency :: proc(pFilter: ^loshelf2) -> uint32 ---
	hishelf2_config_init :: proc(format: format, channels: uint32, sampleRate: uint32, gainDB: f64, shelfSlope: f64, frequency: f64) -> hishelf2_config ---
	hishelf2_get_heap_size :: proc(pConfig: ^hishelf2_config, pHeapSizeInBytes: ^uint) -> result ---
	hishelf2_init_preallocated :: proc(pConfig: ^hishelf2_config, pHeap: rawptr, pFilter: ^hishelf2) -> result ---
	hishelf2_init :: proc(pConfig: ^hishelf2_config, pAllocationCallbacks: ^allocation_callbacks, pFilter: ^hishelf2) -> result ---
	hishelf2_uninit :: proc(pFilter: ^hishelf2, pAllocationCallbacks: ^allocation_callbacks) ---
	hishelf2_reinit :: proc(pConfig: ^hishelf2_config, pFilter: ^hishelf2) -> result ---
	hishelf2_process_pcm_frames :: proc(pFilter: ^hishelf2, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	hishelf2_get_latency :: proc(pFilter: ^hishelf2) -> uint32 ---
	delay_config_init :: proc(channels: uint32, sampleRate: uint32, delayInFrames: uint32, decay: f32) -> delay_config ---
	delay_init :: proc(pConfig: ^delay_config, pAllocationCallbacks: ^allocation_callbacks, pDelay: ^delay) -> result ---
	delay_uninit :: proc(pDelay: ^delay, pAllocationCallbacks: ^allocation_callbacks) ---
	delay_process_pcm_frames :: proc(pDelay: ^delay, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint32) -> result ---
	delay_set_wet :: proc(pDelay: ^delay, value: f32) ---
	delay_get_wet :: proc(pDelay: ^delay) -> f32 ---
	delay_set_dry :: proc(pDelay: ^delay, value: f32) ---
	delay_get_dry :: proc(pDelay: ^delay) -> f32 ---
	delay_set_decay :: proc(pDelay: ^delay, value: f32) ---
	delay_get_decay :: proc(pDelay: ^delay) -> f32 ---
	gainer_config_init :: proc(channels: uint32, smoothTimeInFrames: uint32) -> gainer_config ---
	gainer_get_heap_size :: proc(pConfig: ^gainer_config, pHeapSizeInBytes: ^uint) -> result ---
	gainer_init_preallocated :: proc(pConfig: ^gainer_config, pHeap: rawptr, pGainer: ^gainer) -> result ---
	gainer_init :: proc(pConfig: ^gainer_config, pAllocationCallbacks: ^allocation_callbacks, pGainer: ^gainer) -> result ---
	gainer_uninit :: proc(pGainer: ^gainer, pAllocationCallbacks: ^allocation_callbacks) ---
	gainer_process_pcm_frames :: proc(pGainer: ^gainer, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	gainer_set_gain :: proc(pGainer: ^gainer, newGain: f32) -> result ---
	gainer_set_gains :: proc(pGainer: ^gainer, pNewGains: ^f32) -> result ---
	gainer_set_master_volume :: proc(pGainer: ^gainer, volume: f32) -> result ---
	gainer_get_master_volume :: proc(pGainer: ^gainer, pVolume: ^f32) -> result ---
	panner_config_init :: proc(format: format, channels: uint32) -> panner_config ---
	panner_init :: proc(pConfig: ^panner_config, pPanner: ^panner) -> result ---
	panner_process_pcm_frames :: proc(pPanner: ^panner, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	panner_set_mode :: proc(pPanner: ^panner, mode: pan_mode) ---
	panner_get_mode :: proc(pPanner: ^panner) -> pan_mode ---
	panner_set_pan :: proc(pPanner: ^panner, pan: f32) ---
	panner_get_pan :: proc(pPanner: ^panner) -> f32 ---
	fader_config_init :: proc(format: format, channels: uint32, sampleRate: uint32) -> fader_config ---
	fader_init :: proc(pConfig: ^fader_config, pFader: ^fader) -> result ---
	fader_process_pcm_frames :: proc(pFader: ^fader, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	fader_get_data_format :: proc(pFader: ^fader, pFormat: ^format, pChannels: ^uint32, pSampleRate: ^uint32) ---
	fader_set_fade :: proc(pFader: ^fader, volumeBeg: f32, volumeEnd: f32, lengthInFrames: uint64) ---
	fader_set_fade_ex :: proc(pFader: ^fader, volumeBeg: f32, volumeEnd: f32, lengthInFrames: uint64, startOffsetInFrames: int64) ---
	fader_get_current_volume :: proc(pFader: ^fader) -> f32 ---
	spatializer_listener_config_init :: proc(channelsOut: uint32) -> spatializer_listener_config ---
	spatializer_listener_get_heap_size :: proc(pConfig: ^spatializer_listener_config, pHeapSizeInBytes: ^uint) -> result ---
	spatializer_listener_init_preallocated :: proc(pConfig: ^spatializer_listener_config, pHeap: rawptr, pListener: ^spatializer_listener) -> result ---
	spatializer_listener_init :: proc(pConfig: ^spatializer_listener_config, pAllocationCallbacks: ^allocation_callbacks, pListener: ^spatializer_listener) -> result ---
	spatializer_listener_uninit :: proc(pListener: ^spatializer_listener, pAllocationCallbacks: ^allocation_callbacks) ---
	spatializer_listener_get_channel_map :: proc(pListener: ^spatializer_listener) -> ^channel ---
	spatializer_listener_set_cone :: proc(pListener: ^spatializer_listener, innerAngleInRadians: f32, outerAngleInRadians: f32, outerGain: f32) ---
	spatializer_listener_get_cone :: proc(pListener: ^spatializer_listener, pInnerAngleInRadians: ^f32, pOuterAngleInRadians: ^f32, pOuterGain: ^f32) ---
	spatializer_listener_set_position :: proc(pListener: ^spatializer_listener, x: f32, y: f32, z: f32) ---
	spatializer_listener_get_position :: proc(pListener: ^spatializer_listener) -> vec3f ---
	spatializer_listener_set_direction :: proc(pListener: ^spatializer_listener, x: f32, y: f32, z: f32) ---
	spatializer_listener_get_direction :: proc(pListener: ^spatializer_listener) -> vec3f ---
	spatializer_listener_set_velocity :: proc(pListener: ^spatializer_listener, x: f32, y: f32, z: f32) ---
	spatializer_listener_get_velocity :: proc(pListener: ^spatializer_listener) -> vec3f ---
	spatializer_listener_set_speed_of_sound :: proc(pListener: ^spatializer_listener, speedOfSound: f32) ---
	spatializer_listener_get_speed_of_sound :: proc(pListener: ^spatializer_listener) -> f32 ---
	spatializer_listener_set_world_up :: proc(pListener: ^spatializer_listener, x: f32, y: f32, z: f32) ---
	spatializer_listener_get_world_up :: proc(pListener: ^spatializer_listener) -> vec3f ---
	spatializer_listener_set_enabled :: proc(pListener: ^spatializer_listener, isEnabled: bool32) ---
	spatializer_listener_is_enabled :: proc(pListener: ^spatializer_listener) -> bool32 ---
	spatializer_config_init :: proc(channelsIn: uint32, channelsOut: uint32) -> spatializer_config ---
	spatializer_get_heap_size :: proc(pConfig: ^spatializer_config, pHeapSizeInBytes: ^uint) -> result ---
	spatializer_init_preallocated :: proc(pConfig: ^spatializer_config, pHeap: rawptr, pSpatializer: ^spatializer) -> result ---
	spatializer_init :: proc(pConfig: ^spatializer_config, pAllocationCallbacks: ^allocation_callbacks, pSpatializer: ^spatializer) -> result ---
	spatializer_uninit :: proc(pSpatializer: ^spatializer, pAllocationCallbacks: ^allocation_callbacks) ---
	spatializer_process_pcm_frames :: proc(pSpatializer: ^spatializer, pListener: ^spatializer_listener, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	spatializer_set_master_volume :: proc(pSpatializer: ^spatializer, volume: f32) -> result ---
	spatializer_get_master_volume :: proc(pSpatializer: ^spatializer, pVolume: ^f32) -> result ---
	spatializer_get_input_channels :: proc(pSpatializer: ^spatializer) -> uint32 ---
	spatializer_get_output_channels :: proc(pSpatializer: ^spatializer) -> uint32 ---
	spatializer_set_attenuation_model :: proc(pSpatializer: ^spatializer, attenuationModel: attenuation_model) ---
	spatializer_get_attenuation_model :: proc(pSpatializer: ^spatializer) -> attenuation_model ---
	spatializer_set_positioning :: proc(pSpatializer: ^spatializer, positioning: positioning) ---
	spatializer_get_positioning :: proc(pSpatializer: ^spatializer) -> positioning ---
	spatializer_set_rolloff :: proc(pSpatializer: ^spatializer, rolloff: f32) ---
	spatializer_get_rolloff :: proc(pSpatializer: ^spatializer) -> f32 ---
	spatializer_set_min_gain :: proc(pSpatializer: ^spatializer, minGain: f32) ---
	spatializer_get_min_gain :: proc(pSpatializer: ^spatializer) -> f32 ---
	spatializer_set_max_gain :: proc(pSpatializer: ^spatializer, maxGain: f32) ---
	spatializer_get_max_gain :: proc(pSpatializer: ^spatializer) -> f32 ---
	spatializer_set_min_distance :: proc(pSpatializer: ^spatializer, minDistance: f32) ---
	spatializer_get_min_distance :: proc(pSpatializer: ^spatializer) -> f32 ---
	spatializer_set_max_distance :: proc(pSpatializer: ^spatializer, maxDistance: f32) ---
	spatializer_get_max_distance :: proc(pSpatializer: ^spatializer) -> f32 ---
	spatializer_set_cone :: proc(pSpatializer: ^spatializer, innerAngleInRadians: f32, outerAngleInRadians: f32, outerGain: f32) ---
	spatializer_get_cone :: proc(pSpatializer: ^spatializer, pInnerAngleInRadians: ^f32, pOuterAngleInRadians: ^f32, pOuterGain: ^f32) ---
	spatializer_set_doppler_factor :: proc(pSpatializer: ^spatializer, dopplerFactor: f32) ---
	spatializer_get_doppler_factor :: proc(pSpatializer: ^spatializer) -> f32 ---
	spatializer_set_directional_attenuation_factor :: proc(pSpatializer: ^spatializer, directionalAttenuationFactor: f32) ---
	spatializer_get_directional_attenuation_factor :: proc(pSpatializer: ^spatializer) -> f32 ---
	spatializer_set_position :: proc(pSpatializer: ^spatializer, x: f32, y: f32, z: f32) ---
	spatializer_get_position :: proc(pSpatializer: ^spatializer) -> vec3f ---
	spatializer_set_direction :: proc(pSpatializer: ^spatializer, x: f32, y: f32, z: f32) ---
	spatializer_get_direction :: proc(pSpatializer: ^spatializer) -> vec3f ---
	spatializer_set_velocity :: proc(pSpatializer: ^spatializer, x: f32, y: f32, z: f32) ---
	spatializer_get_velocity :: proc(pSpatializer: ^spatializer) -> vec3f ---
	spatializer_get_relative_position_and_direction :: proc(pSpatializer: ^spatializer, pListener: ^spatializer_listener, pRelativePos: ^vec3f, pRelativeDir: ^vec3f) ---
	linear_resampler_config_init :: proc(format: format, channels: uint32, sampleRateIn: uint32, sampleRateOut: uint32) -> linear_resampler_config ---
	linear_resampler_get_heap_size :: proc(pConfig: ^linear_resampler_config, pHeapSizeInBytes: ^uint) -> result ---
	linear_resampler_init_preallocated :: proc(pConfig: ^linear_resampler_config, pHeap: rawptr, pResampler: ^linear_resampler) -> result ---
	linear_resampler_init :: proc(pConfig: ^linear_resampler_config, pAllocationCallbacks: ^allocation_callbacks, pResampler: ^linear_resampler) -> result ---
	linear_resampler_uninit :: proc(pResampler: ^linear_resampler, pAllocationCallbacks: ^allocation_callbacks) ---
	linear_resampler_process_pcm_frames :: proc(pResampler: ^linear_resampler, pFramesIn: rawptr, pFrameCountIn: ^uint64, pFramesOut: rawptr, pFrameCountOut: ^uint64) -> result ---
	linear_resampler_set_rate :: proc(pResampler: ^linear_resampler, sampleRateIn: uint32, sampleRateOut: uint32) -> result ---
	linear_resampler_set_rate_ratio :: proc(pResampler: ^linear_resampler, ratioInOut: f32) -> result ---
	linear_resampler_get_input_latency :: proc(pResampler: ^linear_resampler) -> uint64 ---
	linear_resampler_get_output_latency :: proc(pResampler: ^linear_resampler) -> uint64 ---
	linear_resampler_get_required_input_frame_count :: proc(pResampler: ^linear_resampler, outputFrameCount: uint64, pInputFrameCount: ^uint64) -> result ---
	linear_resampler_get_expected_output_frame_count :: proc(pResampler: ^linear_resampler, inputFrameCount: uint64, pOutputFrameCount: ^uint64) -> result ---
	linear_resampler_reset :: proc(pResampler: ^linear_resampler) -> result ---
	resampler_config_init :: proc(format: format, channels: uint32, sampleRateIn: uint32, sampleRateOut: uint32, algorithm: resample_algorithm) -> resampler_config ---
	resampler_get_heap_size :: proc(pConfig: ^resampler_config, pHeapSizeInBytes: ^uint) -> result ---
	resampler_init_preallocated :: proc(pConfig: ^resampler_config, pHeap: rawptr, pResampler: ^resampler) -> result ---
	/*
	Initializes a new resampler object from a config.
	*/
	resampler_init :: proc(pConfig: ^resampler_config, pAllocationCallbacks: ^allocation_callbacks, pResampler: ^resampler) -> result ---
	/*
	Uninitializes a resampler.
	*/
	resampler_uninit :: proc(pResampler: ^resampler, pAllocationCallbacks: ^allocation_callbacks) ---
	/*
	Converts the given input data.
	
	Both the input and output frames must be in the format specified in the config when the resampler was initialized.
	
	On input, [pFrameCountOut] contains the number of output frames to process. On output it contains the number of output frames that
	were actually processed, which may be less than the requested amount which will happen if there's not enough input data. You can use
	ma_resampler_get_expected_output_frame_count() to know how many output frames will be processed for a given number of input frames.
	
	On input, [pFrameCountIn] contains the number of input frames contained in [pFramesIn]. On output it contains the number of whole
	input frames that were actually processed. You can use ma_resampler_get_required_input_frame_count() to know how many input frames
	you should provide for a given number of output frames. [pFramesIn] can be NULL, in which case zeroes will be used instead.
	
	If [pFramesOut] is NULL, a seek is performed. In this case, if [pFrameCountOut] is not NULL it will seek by the specified number of
	output frames. Otherwise, if [pFramesCountOut] is NULL and [pFrameCountIn] is not NULL, it will seek by the specified number of input
	frames. When seeking, [pFramesIn] is allowed to NULL, in which case the internal timing state will be updated, but no input will be
	processed. In this case, any internal filter state will be updated as if zeroes were passed in.
	
	It is an error for [pFramesOut] to be non-NULL and [pFrameCountOut] to be NULL.
	
	It is an error for both [pFrameCountOut] and [pFrameCountIn] to be NULL.
	*/
	resampler_process_pcm_frames :: proc(pResampler: ^resampler, pFramesIn: rawptr, pFrameCountIn: ^uint64, pFramesOut: rawptr, pFrameCountOut: ^uint64) -> result ---
	/*
	Sets the input and output sample rate.
	*/
	resampler_set_rate :: proc(pResampler: ^resampler, sampleRateIn: uint32, sampleRateOut: uint32) -> result ---
	/*
	Sets the input and output sample rate as a ratio.
	
	The ration is in/out.
	*/
	resampler_set_rate_ratio :: proc(pResampler: ^resampler, ratio: f32) -> result ---
	/*
	Retrieves the latency introduced by the resampler in input frames.
	*/
	resampler_get_input_latency :: proc(pResampler: ^resampler) -> uint64 ---
	/*
	Retrieves the latency introduced by the resampler in output frames.
	*/
	resampler_get_output_latency :: proc(pResampler: ^resampler) -> uint64 ---
	/*
	Calculates the number of whole input frames that would need to be read from the client in order to output the specified
	number of output frames.
	
	The returned value does not include cached input frames. It only returns the number of extra frames that would need to be
	read from the input buffer in order to output the specified number of output frames.
	*/
	resampler_get_required_input_frame_count :: proc(pResampler: ^resampler, outputFrameCount: uint64, pInputFrameCount: ^uint64) -> result ---
	/*
	Calculates the number of whole output frames that would be output after fully reading and consuming the specified number of
	input frames.
	*/
	resampler_get_expected_output_frame_count :: proc(pResampler: ^resampler, inputFrameCount: uint64, pOutputFrameCount: ^uint64) -> result ---
	/*
	Resets the resampler's timer and clears its internal cache.
	*/
	resampler_reset :: proc(pResampler: ^resampler) -> result ---
	channel_converter_config_init :: proc(format: format, channelsIn: uint32, pChannelMapIn: ^channel, channelsOut: uint32, pChannelMapOut: ^channel, mixingMode: channel_mix_mode) -> channel_converter_config ---
	channel_converter_get_heap_size :: proc(pConfig: ^channel_converter_config, pHeapSizeInBytes: ^uint) -> result ---
	channel_converter_init_preallocated :: proc(pConfig: ^channel_converter_config, pHeap: rawptr, pConverter: ^channel_converter) -> result ---
	channel_converter_init :: proc(pConfig: ^channel_converter_config, pAllocationCallbacks: ^allocation_callbacks, pConverter: ^channel_converter) -> result ---
	channel_converter_uninit :: proc(pConverter: ^channel_converter, pAllocationCallbacks: ^allocation_callbacks) ---
	channel_converter_process_pcm_frames :: proc(pConverter: ^channel_converter, pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64) -> result ---
	channel_converter_get_input_channel_map :: proc(pConverter: ^channel_converter, pChannelMap: ^channel, channelMapCap: uint) -> result ---
	channel_converter_get_output_channel_map :: proc(pConverter: ^channel_converter, pChannelMap: ^channel, channelMapCap: uint) -> result ---
	data_converter_config_init_default :: proc() -> data_converter_config ---
	data_converter_config_init :: proc(formatIn: format, formatOut: format, channelsIn: uint32, channelsOut: uint32, sampleRateIn: uint32, sampleRateOut: uint32) -> data_converter_config ---
	data_converter_get_heap_size :: proc(pConfig: ^data_converter_config, pHeapSizeInBytes: ^uint) -> result ---
	data_converter_init_preallocated :: proc(pConfig: ^data_converter_config, pHeap: rawptr, pConverter: ^data_converter) -> result ---
	data_converter_init :: proc(pConfig: ^data_converter_config, pAllocationCallbacks: ^allocation_callbacks, pConverter: ^data_converter) -> result ---
	data_converter_uninit :: proc(pConverter: ^data_converter, pAllocationCallbacks: ^allocation_callbacks) ---
	data_converter_process_pcm_frames :: proc(pConverter: ^data_converter, pFramesIn: rawptr, pFrameCountIn: ^uint64, pFramesOut: rawptr, pFrameCountOut: ^uint64) -> result ---
	data_converter_set_rate :: proc(pConverter: ^data_converter, sampleRateIn: uint32, sampleRateOut: uint32) -> result ---
	data_converter_set_rate_ratio :: proc(pConverter: ^data_converter, ratioInOut: f32) -> result ---
	data_converter_get_input_latency :: proc(pConverter: ^data_converter) -> uint64 ---
	data_converter_get_output_latency :: proc(pConverter: ^data_converter) -> uint64 ---
	data_converter_get_required_input_frame_count :: proc(pConverter: ^data_converter, outputFrameCount: uint64, pInputFrameCount: ^uint64) -> result ---
	data_converter_get_expected_output_frame_count :: proc(pConverter: ^data_converter, inputFrameCount: uint64, pOutputFrameCount: ^uint64) -> result ---
	data_converter_get_input_channel_map :: proc(pConverter: ^data_converter, pChannelMap: ^channel, channelMapCap: uint) -> result ---
	data_converter_get_output_channel_map :: proc(pConverter: ^data_converter, pChannelMap: ^channel, channelMapCap: uint) -> result ---
	data_converter_reset :: proc(pConverter: ^data_converter) -> result ---
	/************************************************************************************************************************************************************
	
	Format Conversion
	
	************************************************************************************************************************************************************/
	pcm_u8_to_s16 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_u8_to_s24 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_u8_to_s32 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_u8_to_f32 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_s16_to_u8 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_s16_to_s24 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_s16_to_s32 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_s16_to_f32 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_s24_to_u8 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_s24_to_s16 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_s24_to_s32 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_s24_to_f32 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_s32_to_u8 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_s32_to_s16 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_s32_to_s24 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_s32_to_f32 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_f32_to_u8 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_f32_to_s16 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_f32_to_s24 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_f32_to_s32 :: proc(pOut: rawptr, pIn: rawptr, count: uint64, ditherMode: dither_mode) ---
	pcm_convert :: proc(pOut: rawptr, formatOut: format, pIn: rawptr, formatIn: format, sampleCount: uint64, ditherMode: dither_mode) ---
	convert_pcm_frames_format :: proc(pOut: rawptr, formatOut: format, pIn: rawptr, formatIn: format, frameCount: uint64, channels: uint32, ditherMode: dither_mode) ---
	/*
	Deinterleaves an interleaved buffer.
	*/
	deinterleave_pcm_frames :: proc(format: format, channels: uint32, frameCount: uint64, pInterleavedPCMFrames: rawptr, ppDeinterleavedPCMFrames: ^rawptr) ---
	/*
	Interleaves a group of deinterleaved buffers.
	*/
	interleave_pcm_frames :: proc(format: format, channels: uint32, frameCount: uint64, ppDeinterleavedPCMFrames: ^rawptr, pInterleavedPCMFrames: rawptr) ---
	/*
	Retrieves the channel position of the specified channel in the given channel map.
	
	The pChannelMap parameter can be null, in which case miniaudio's default channel map will be assumed.
	*/
	channel_map_get_channel :: proc(pChannelMap: ^channel, channelCount: uint32, channelIndex: uint32) -> channel ---
	/*
	Initializes a blank channel map.
	
	When a blank channel map is specified anywhere it indicates that the native channel map should be used.
	*/
	channel_map_init_blank :: proc(pChannelMap: ^channel, channels: uint32) ---
	/*
	Helper for retrieving a standard channel map.
	
	The output channel map buffer must have a capacity of at least `channelMapCap`.
	*/
	channel_map_init_standard :: proc(standardChannelMap: standard_channel_map, pChannelMap: ^channel, channelMapCap: uint, channels: uint32) ---
	/*
	Copies a channel map.
	
	Both input and output channel map buffers must have a capacity of at least `channels`.
	*/
	channel_map_copy :: proc(pOut: ^channel, pIn: ^channel, channels: uint32) ---
	/*
	Copies a channel map if one is specified, otherwise copies the default channel map.
	
	The output buffer must have a capacity of at least `channels`. If not NULL, the input channel map must also have a capacity of at least `channels`.
	*/
	channel_map_copy_or_default :: proc(pOut: ^channel, channelMapCapOut: uint, pIn: ^channel, channels: uint32) ---
	/*
	Determines whether or not a channel map is valid.
	
	A blank channel map is valid (all channels set to MA_CHANNEL_NONE). The way a blank channel map is handled is context specific, but
	is usually treated as a passthrough.
	
	Invalid channel maps:
	  - A channel map with no channels
	  - A channel map with more than one channel and a mono channel
	
	The channel map buffer must have a capacity of at least `channels`.
	*/
	channel_map_is_valid :: proc(pChannelMap: ^channel, channels: uint32) -> bool32 ---
	/*
	Helper for comparing two channel maps for equality.
	
	This assumes the channel count is the same between the two.
	
	Both channels map buffers must have a capacity of at least `channels`.
	*/
	channel_map_is_equal :: proc(pChannelMapA: ^channel, pChannelMapB: ^channel, channels: uint32) -> bool32 ---
	/*
	Helper for determining if a channel map is blank (all channels set to MA_CHANNEL_NONE).
	
	The channel map buffer must have a capacity of at least `channels`.
	*/
	channel_map_is_blank :: proc(pChannelMap: ^channel, channels: uint32) -> bool32 ---
	/*
	Helper for determining whether or not a channel is present in the given channel map.
	
	The channel map buffer must have a capacity of at least `channels`.
	*/
	channel_map_contains_channel_position :: proc(channels: uint32, pChannelMap: ^channel, channelPosition: channel) -> bool32 ---
	/*
	Find a channel position in the given channel map. Returns MA_TRUE if the channel is found; MA_FALSE otherwise. The
	index of the channel is output to `pChannelIndex`.
	
	The channel map buffer must have a capacity of at least `channels`.
	*/
	channel_map_find_channel_position :: proc(channels: uint32, pChannelMap: ^channel, channelPosition: channel, pChannelIndex: ^uint32) -> bool32 ---
	/*
	Generates a string representing the given channel map.
	
	This is for printing and debugging purposes, not serialization/deserialization.
	
	Returns the length of the string, not including the null terminator.
	*/
	channel_map_to_string :: proc(pChannelMap: ^channel, channels: uint32, pBufferOut: ^u8, bufferCap: uint) -> uint ---
	/*
	Retrieves a human readable version of a channel position.
	*/
	channel_position_to_string :: proc(channel: channel) -> cstring ---
	/*
	High-level helper for doing a full format conversion in one go. Returns the number of output frames. Call this with pOut set to NULL to
	determine the required size of the output buffer. frameCountOut should be set to the capacity of pOut. If pOut is NULL, frameCountOut is
	ignored.
	
	A return value of 0 indicates an error.
	
	This function is useful for one-off bulk conversions, but if you're streaming data you should use the ma_data_converter APIs instead.
	*/
	convert_frames :: proc(pOut: rawptr, frameCountOut: uint64, formatOut: format, channelsOut: uint32, sampleRateOut: uint32, pIn: rawptr, frameCountIn: uint64, formatIn: format, channelsIn: uint32, sampleRateIn: uint32) -> uint64 ---
	convert_frames_ex :: proc(pOut: rawptr, frameCountOut: uint64, pIn: rawptr, frameCountIn: uint64, pConfig: ^data_converter_config) -> uint64 ---
	data_source_config_init :: proc() -> data_source_config ---
	data_source_init :: proc(pConfig: ^data_source_config, pDataSource: ^ma_data_source) -> result ---
	data_source_uninit :: proc(pDataSource: ^ma_data_source) ---
	data_source_read_pcm_frames :: proc(pDataSource: ^ma_data_source, pFramesOut: rawptr, frameCount: uint64, pFramesRead: ^uint64) -> result ---
	data_source_seek_pcm_frames :: proc(pDataSource: ^ma_data_source, frameCount: uint64, pFramesSeeked: ^uint64) -> result ---
	data_source_seek_to_pcm_frame :: proc(pDataSource: ^ma_data_source, frameIndex: uint64) -> result ---
	data_source_seek_seconds :: proc(pDataSource: ^ma_data_source, secondCount: f32, pSecondsSeeked: ^f32) -> result ---
	data_source_seek_to_second :: proc(pDataSource: ^ma_data_source, seekPointInSeconds: f32) -> result ---
	data_source_get_data_format :: proc(pDataSource: ^ma_data_source, pFormat: ^format, pChannels: ^uint32, pSampleRate: ^uint32, pChannelMap: ^channel, channelMapCap: uint) -> result ---
	data_source_get_cursor_in_pcm_frames :: proc(pDataSource: ^ma_data_source, pCursor: ^uint64) -> result ---
	data_source_get_length_in_pcm_frames :: proc(pDataSource: ^ma_data_source, pLength: ^uint64) -> result ---
	data_source_get_cursor_in_seconds :: proc(pDataSource: ^ma_data_source, pCursor: ^f32) -> result ---
	data_source_get_length_in_seconds :: proc(pDataSource: ^ma_data_source, pLength: ^f32) -> result ---
	data_source_set_looping :: proc(pDataSource: ^ma_data_source, isLooping: bool32) -> result ---
	data_source_is_looping :: proc(pDataSource: ^ma_data_source) -> bool32 ---
	data_source_set_range_in_pcm_frames :: proc(pDataSource: ^ma_data_source, rangeBegInFrames: uint64, rangeEndInFrames: uint64) -> result ---
	data_source_get_range_in_pcm_frames :: proc(pDataSource: ^ma_data_source, pRangeBegInFrames: ^uint64, pRangeEndInFrames: ^uint64) ---
	data_source_set_loop_point_in_pcm_frames :: proc(pDataSource: ^ma_data_source, loopBegInFrames: uint64, loopEndInFrames: uint64) -> result ---
	data_source_get_loop_point_in_pcm_frames :: proc(pDataSource: ^ma_data_source, pLoopBegInFrames: ^uint64, pLoopEndInFrames: ^uint64) ---
	data_source_set_current :: proc(pDataSource: ^ma_data_source, pCurrentDataSource: ^ma_data_source) -> result ---
	data_source_get_current :: proc(pDataSource: ^ma_data_source) -> ^ma_data_source ---
	data_source_set_next :: proc(pDataSource: ^ma_data_source, pNextDataSource: ^ma_data_source) -> result ---
	data_source_get_next :: proc(pDataSource: ^ma_data_source) -> ^ma_data_source ---
	data_source_set_next_callback :: proc(pDataSource: ^ma_data_source, onGetNext: data_source_get_next_proc) -> result ---
	data_source_get_next_callback :: proc(pDataSource: ^ma_data_source) -> data_source_get_next_proc ---
	audio_buffer_ref_init :: proc(format: format, channels: uint32, pData: rawptr, sizeInFrames: uint64, pAudioBufferRef: ^audio_buffer_ref) -> result ---
	audio_buffer_ref_uninit :: proc(pAudioBufferRef: ^audio_buffer_ref) ---
	audio_buffer_ref_set_data :: proc(pAudioBufferRef: ^audio_buffer_ref, pData: rawptr, sizeInFrames: uint64) -> result ---
	audio_buffer_ref_read_pcm_frames :: proc(pAudioBufferRef: ^audio_buffer_ref, pFramesOut: rawptr, frameCount: uint64, loop: bool32) -> uint64 ---
	audio_buffer_ref_seek_to_pcm_frame :: proc(pAudioBufferRef: ^audio_buffer_ref, frameIndex: uint64) -> result ---
	audio_buffer_ref_map :: proc(pAudioBufferRef: ^audio_buffer_ref, ppFramesOut: ^rawptr, pFrameCount: ^uint64) -> result ---
	audio_buffer_ref_unmap :: proc(pAudioBufferRef: ^audio_buffer_ref, frameCount: uint64) -> result ---
	audio_buffer_ref_at_end :: proc(pAudioBufferRef: ^audio_buffer_ref) -> bool32 ---
	audio_buffer_ref_get_cursor_in_pcm_frames :: proc(pAudioBufferRef: ^audio_buffer_ref, pCursor: ^uint64) -> result ---
	audio_buffer_ref_get_length_in_pcm_frames :: proc(pAudioBufferRef: ^audio_buffer_ref, pLength: ^uint64) -> result ---
	audio_buffer_ref_get_available_frames :: proc(pAudioBufferRef: ^audio_buffer_ref, pAvailableFrames: ^uint64) -> result ---
	audio_buffer_config_init :: proc(format: format, channels: uint32, sizeInFrames: uint64, pData: rawptr, pAllocationCallbacks: ^allocation_callbacks) -> audio_buffer_config ---
	audio_buffer_init :: proc(pConfig: ^audio_buffer_config, pAudioBuffer: ^audio_buffer) -> result ---
	audio_buffer_init_copy :: proc(pConfig: ^audio_buffer_config, pAudioBuffer: ^audio_buffer) -> result ---
	audio_buffer_alloc_and_init :: proc(pConfig: ^audio_buffer_config, ppAudioBuffer: ^^audio_buffer) -> result ---
	audio_buffer_uninit :: proc(pAudioBuffer: ^audio_buffer) ---
	audio_buffer_uninit_and_free :: proc(pAudioBuffer: ^audio_buffer) ---
	audio_buffer_read_pcm_frames :: proc(pAudioBuffer: ^audio_buffer, pFramesOut: rawptr, frameCount: uint64, loop: bool32) -> uint64 ---
	audio_buffer_seek_to_pcm_frame :: proc(pAudioBuffer: ^audio_buffer, frameIndex: uint64) -> result ---
	audio_buffer_map :: proc(pAudioBuffer: ^audio_buffer, ppFramesOut: ^rawptr, pFrameCount: ^uint64) -> result ---
	audio_buffer_unmap :: proc(pAudioBuffer: ^audio_buffer, frameCount: uint64) -> result ---
	audio_buffer_at_end :: proc(pAudioBuffer: ^audio_buffer) -> bool32 ---
	audio_buffer_get_cursor_in_pcm_frames :: proc(pAudioBuffer: ^audio_buffer, pCursor: ^uint64) -> result ---
	audio_buffer_get_length_in_pcm_frames :: proc(pAudioBuffer: ^audio_buffer, pLength: ^uint64) -> result ---
	audio_buffer_get_available_frames :: proc(pAudioBuffer: ^audio_buffer, pAvailableFrames: ^uint64) -> result ---
	paged_audio_buffer_data_init :: proc(format: format, channels: uint32, pData: ^paged_audio_buffer_data) -> result ---
	paged_audio_buffer_data_uninit :: proc(pData: ^paged_audio_buffer_data, pAllocationCallbacks: ^allocation_callbacks) ---
	paged_audio_buffer_data_get_head :: proc(pData: ^paged_audio_buffer_data) -> ^paged_audio_buffer_page ---
	paged_audio_buffer_data_get_tail :: proc(pData: ^paged_audio_buffer_data) -> ^paged_audio_buffer_page ---
	paged_audio_buffer_data_get_length_in_pcm_frames :: proc(pData: ^paged_audio_buffer_data, pLength: ^uint64) -> result ---
	paged_audio_buffer_data_allocate_page :: proc(pData: ^paged_audio_buffer_data, pageSizeInFrames: uint64, pInitialData: rawptr, pAllocationCallbacks: ^allocation_callbacks, ppPage: ^^paged_audio_buffer_page) -> result ---
	paged_audio_buffer_data_free_page :: proc(pData: ^paged_audio_buffer_data, pPage: ^paged_audio_buffer_page, pAllocationCallbacks: ^allocation_callbacks) -> result ---
	paged_audio_buffer_data_append_page :: proc(pData: ^paged_audio_buffer_data, pPage: ^paged_audio_buffer_page) -> result ---
	paged_audio_buffer_data_allocate_and_append_page :: proc(pData: ^paged_audio_buffer_data, pageSizeInFrames: uint32, pInitialData: rawptr, pAllocationCallbacks: ^allocation_callbacks) -> result ---
	paged_audio_buffer_config_init :: proc(pData: ^paged_audio_buffer_data) -> paged_audio_buffer_config ---
	paged_audio_buffer_init :: proc(pConfig: ^paged_audio_buffer_config, pPagedAudioBuffer: ^paged_audio_buffer) -> result ---
	paged_audio_buffer_uninit :: proc(pPagedAudioBuffer: ^paged_audio_buffer) ---
	paged_audio_buffer_read_pcm_frames :: proc(pPagedAudioBuffer: ^paged_audio_buffer, pFramesOut: rawptr, frameCount: uint64, pFramesRead: ^uint64) -> result ---
	paged_audio_buffer_seek_to_pcm_frame :: proc(pPagedAudioBuffer: ^paged_audio_buffer, frameIndex: uint64) -> result ---
	paged_audio_buffer_get_cursor_in_pcm_frames :: proc(pPagedAudioBuffer: ^paged_audio_buffer, pCursor: ^uint64) -> result ---
	paged_audio_buffer_get_length_in_pcm_frames :: proc(pPagedAudioBuffer: ^paged_audio_buffer, pLength: ^uint64) -> result ---
	rb_init_ex :: proc(subbufferSizeInBytes: uint, subbufferCount: uint, subbufferStrideInBytes: uint, pOptionalPreallocatedBuffer: rawptr, pAllocationCallbacks: ^allocation_callbacks, pRB: ^rb) -> result ---
	rb_init :: proc(bufferSizeInBytes: uint, pOptionalPreallocatedBuffer: rawptr, pAllocationCallbacks: ^allocation_callbacks, pRB: ^rb) -> result ---
	rb_uninit :: proc(pRB: ^rb) ---
	rb_reset :: proc(pRB: ^rb) ---
	rb_acquire_read :: proc(pRB: ^rb, pSizeInBytes: ^uint, ppBufferOut: ^rawptr) -> result ---
	rb_commit_read :: proc(pRB: ^rb, sizeInBytes: uint) -> result ---
	rb_acquire_write :: proc(pRB: ^rb, pSizeInBytes: ^uint, ppBufferOut: ^rawptr) -> result ---
	rb_commit_write :: proc(pRB: ^rb, sizeInBytes: uint) -> result ---
	rb_seek_read :: proc(pRB: ^rb, offsetInBytes: uint) -> result ---
	rb_seek_write :: proc(pRB: ^rb, offsetInBytes: uint) -> result ---
	rb_pointer_distance :: proc(pRB: ^rb) -> int32 ---
	rb_available_read :: proc(pRB: ^rb) -> uint32 ---
	rb_available_write :: proc(pRB: ^rb) -> uint32 ---
	rb_get_subbuffer_size :: proc(pRB: ^rb) -> uint ---
	rb_get_subbuffer_stride :: proc(pRB: ^rb) -> uint ---
	rb_get_subbuffer_offset :: proc(pRB: ^rb, subbufferIndex: uint) -> uint ---
	rb_get_subbuffer_ptr :: proc(pRB: ^rb, subbufferIndex: uint, pBuffer: rawptr) -> rawptr ---
	pcm_rb_init_ex :: proc(format: format, channels: uint32, subbufferSizeInFrames: uint32, subbufferCount: uint32, subbufferStrideInFrames: uint32, pOptionalPreallocatedBuffer: rawptr, pAllocationCallbacks: ^allocation_callbacks, pRB: ^pcm_rb) -> result ---
	pcm_rb_init :: proc(format: format, channels: uint32, bufferSizeInFrames: uint32, pOptionalPreallocatedBuffer: rawptr, pAllocationCallbacks: ^allocation_callbacks, pRB: ^pcm_rb) -> result ---
	pcm_rb_uninit :: proc(pRB: ^pcm_rb) ---
	pcm_rb_reset :: proc(pRB: ^pcm_rb) ---
	pcm_rb_acquire_read :: proc(pRB: ^pcm_rb, pSizeInFrames: ^uint32, ppBufferOut: ^rawptr) -> result ---
	pcm_rb_commit_read :: proc(pRB: ^pcm_rb, sizeInFrames: uint32) -> result ---
	pcm_rb_acquire_write :: proc(pRB: ^pcm_rb, pSizeInFrames: ^uint32, ppBufferOut: ^rawptr) -> result ---
	pcm_rb_commit_write :: proc(pRB: ^pcm_rb, sizeInFrames: uint32) -> result ---
	pcm_rb_seek_read :: proc(pRB: ^pcm_rb, offsetInFrames: uint32) -> result ---
	pcm_rb_seek_write :: proc(pRB: ^pcm_rb, offsetInFrames: uint32) -> result ---
	pcm_rb_pointer_distance :: proc(pRB: ^pcm_rb) -> int32 ---
	pcm_rb_available_read :: proc(pRB: ^pcm_rb) -> uint32 ---
	pcm_rb_available_write :: proc(pRB: ^pcm_rb) -> uint32 ---
	pcm_rb_get_subbuffer_size :: proc(pRB: ^pcm_rb) -> uint32 ---
	pcm_rb_get_subbuffer_stride :: proc(pRB: ^pcm_rb) -> uint32 ---
	pcm_rb_get_subbuffer_offset :: proc(pRB: ^pcm_rb, subbufferIndex: uint32) -> uint32 ---
	pcm_rb_get_subbuffer_ptr :: proc(pRB: ^pcm_rb, subbufferIndex: uint32, pBuffer: rawptr) -> rawptr ---
	pcm_rb_get_format :: proc(pRB: ^pcm_rb) -> format ---
	pcm_rb_get_channels :: proc(pRB: ^pcm_rb) -> uint32 ---
	pcm_rb_get_sample_rate :: proc(pRB: ^pcm_rb) -> uint32 ---
	pcm_rb_set_sample_rate :: proc(pRB: ^pcm_rb, sampleRate: uint32) ---
	duplex_rb_init :: proc(captureFormat: format, captureChannels: uint32, sampleRate: uint32, captureInternalSampleRate: uint32, captureInternalPeriodSizeInFrames: uint32, pAllocationCallbacks: ^allocation_callbacks, pRB: ^duplex_rb) -> result ---
	duplex_rb_uninit :: proc(pRB: ^duplex_rb) -> result ---
	/************************************************************************************************************************************************************
	
	Miscellaneous Helpers
	
	************************************************************************************************************************************************************/
	/*
	Retrieves a human readable description of the given result code.
	*/
	result_description :: proc(result: result) -> cstring ---
	/*
	malloc()
	*/
	malloc :: proc(sz: uint, pAllocationCallbacks: ^allocation_callbacks) -> rawptr ---
	/*
	calloc()
	*/
	calloc :: proc(sz: uint, pAllocationCallbacks: ^allocation_callbacks) -> rawptr ---
	/*
	realloc()
	*/
	realloc :: proc(p: rawptr, sz: uint, pAllocationCallbacks: ^allocation_callbacks) -> rawptr ---
	/*
	free()
	*/
	free :: proc(p: rawptr, pAllocationCallbacks: ^allocation_callbacks) ---
	/*
	Performs an aligned malloc, with the assumption that the alignment is a power of 2.
	*/
	aligned_malloc :: proc(sz: uint, alignment: uint, pAllocationCallbacks: ^allocation_callbacks) -> rawptr ---
	/*
	Free's an aligned malloc'd buffer.
	*/
	aligned_free :: proc(p: rawptr, pAllocationCallbacks: ^allocation_callbacks) ---
	/*
	Retrieves a friendly name for a format.
	*/
	get_format_name :: proc(format: format) -> cstring ---
	/*
	Blends two frames in floating point format.
	*/
	blend_f32 :: proc(pOut: ^f32, pInA: ^f32, pInB: ^f32, factor: f32, channels: uint32) ---
	/*
	Retrieves the size of a sample in bytes for the given format.
	
	This API is efficient and is implemented using a lookup table.
	
	Thread Safety: SAFE
	  This API is pure.
	*/
	get_bytes_per_sample :: proc(format: format) -> uint32 ---
	/*
	Converts a log level to a string.
	*/
	log_level_to_string :: proc(logLevel: uint32) -> cstring ---
	/************************************************************************************************************************************************************
	
	Synchronization
	
	************************************************************************************************************************************************************/
	/*
	Locks a spinlock.
	*/
	spinlock_lock :: proc(pSpinlock: ^spinlock) -> result ---
	/*
	Locks a spinlock, but does not yield() when looping.
	*/
	spinlock_lock_noyield :: proc(pSpinlock: ^spinlock) -> result ---
	/*
	Unlocks a spinlock.
	*/
	spinlock_unlock :: proc(pSpinlock: ^spinlock) -> result ---
	/*
	Creates a mutex.
	
	A mutex must be created from a valid context. A mutex is initially unlocked.
	*/
	mutex_init :: proc(pMutex: ^mutex) -> result ---
	/*
	Deletes a mutex.
	*/
	mutex_uninit :: proc(pMutex: ^mutex) ---
	/*
	Locks a mutex with an infinite timeout.
	*/
	mutex_lock :: proc(pMutex: ^mutex) ---
	/*
	Unlocks a mutex.
	*/
	mutex_unlock :: proc(pMutex: ^mutex) ---
	/*
	Initializes an auto-reset event.
	*/
	event_init :: proc(pEvent: ^event) -> result ---
	/*
	Uninitializes an auto-reset event.
	*/
	event_uninit :: proc(pEvent: ^event) ---
	/*
	Waits for the specified auto-reset event to become signalled.
	*/
	event_wait :: proc(pEvent: ^event) -> result ---
	/*
	Signals the specified auto-reset event.
	*/
	event_signal :: proc(pEvent: ^event) -> result ---
	semaphore_init :: proc(initialValue: i32, pSemaphore: ^semaphore) -> result ---
	semaphore_uninit :: proc(pSemaphore: ^semaphore) ---
	semaphore_wait :: proc(pSemaphore: ^semaphore) -> result ---
	semaphore_release :: proc(pSemaphore: ^semaphore) -> result ---
	fence_init :: proc(pFence: ^fence) -> result ---
	fence_uninit :: proc(pFence: ^fence) ---
	fence_acquire :: proc(pFence: ^fence) -> result ---
	fence_release :: proc(pFence: ^fence) -> result ---
	fence_wait :: proc(pFence: ^fence) -> result ---
	async_notification_signal :: proc(pNotification: ^ma_async_notification) -> result ---
	async_notification_poll_init :: proc(pNotificationPoll: ^async_notification_poll) -> result ---
	async_notification_poll_is_signalled :: proc(pNotificationPoll: ^async_notification_poll) -> bool32 ---
	async_notification_event_init :: proc(pNotificationEvent: ^async_notification_event) -> result ---
	async_notification_event_uninit :: proc(pNotificationEvent: ^async_notification_event) -> result ---
	async_notification_event_wait :: proc(pNotificationEvent: ^async_notification_event) -> result ---
	async_notification_event_signal :: proc(pNotificationEvent: ^async_notification_event) -> result ---
	slot_allocator_config_init :: proc(capacity: uint32) -> slot_allocator_config ---
	slot_allocator_get_heap_size :: proc(pConfig: ^slot_allocator_config, pHeapSizeInBytes: ^uint) -> result ---
	slot_allocator_init_preallocated :: proc(pConfig: ^slot_allocator_config, pHeap: rawptr, pAllocator: ^slot_allocator) -> result ---
	slot_allocator_init :: proc(pConfig: ^slot_allocator_config, pAllocationCallbacks: ^allocation_callbacks, pAllocator: ^slot_allocator) -> result ---
	slot_allocator_uninit :: proc(pAllocator: ^slot_allocator, pAllocationCallbacks: ^allocation_callbacks) ---
	slot_allocator_alloc :: proc(pAllocator: ^slot_allocator, pSlot: ^uint64) -> result ---
	slot_allocator_free :: proc(pAllocator: ^slot_allocator, slot: uint64) -> result ---
	job_init :: proc(code: uint16) -> job ---
	job_process :: proc(pJob: ^job) -> result ---
	job_queue_config_init :: proc(flags: uint32, capacity: uint32) -> job_queue_config ---
	job_queue_get_heap_size :: proc(pConfig: ^job_queue_config, pHeapSizeInBytes: ^uint) -> result ---
	job_queue_init_preallocated :: proc(pConfig: ^job_queue_config, pHeap: rawptr, pQueue: ^job_queue) -> result ---
	job_queue_init :: proc(pConfig: ^job_queue_config, pAllocationCallbacks: ^allocation_callbacks, pQueue: ^job_queue) -> result ---
	job_queue_uninit :: proc(pQueue: ^job_queue, pAllocationCallbacks: ^allocation_callbacks) ---
	job_queue_post :: proc(pQueue: ^job_queue, pJob: ^job) -> result ---
	job_queue_next :: proc(pQueue: ^job_queue, pJob: ^job) -> result ---
	device_job_thread_config_init :: proc() -> device_job_thread_config ---
	device_job_thread_init :: proc(pConfig: ^device_job_thread_config, pAllocationCallbacks: ^allocation_callbacks, pJobThread: ^device_job_thread) -> result ---
	device_job_thread_uninit :: proc(pJobThread: ^device_job_thread, pAllocationCallbacks: ^allocation_callbacks) ---
	device_job_thread_post :: proc(pJobThread: ^device_job_thread, pJob: ^job) -> result ---
	device_job_thread_next :: proc(pJobThread: ^device_job_thread, pJob: ^job) -> result ---
	device_id_equal :: proc(pA: ^device_id, pB: ^device_id) -> bool32 ---
	/*
	Initializes a `ma_context_config` object.
	
	
	Return Value
	------------
	A `ma_context_config` initialized to defaults.
	
	
	Remarks
	-------
	You must always use this to initialize the default state of the `ma_context_config` object. Not using this will result in your program breaking when miniaudio
	is updated and new members are added to `ma_context_config`. It also sets logical defaults.
	
	You can override members of the returned object by changing it's members directly.
	
	
	See Also
	--------
	ma_context_init()
	*/
	context_config_init :: proc() -> context_config ---
	/*
	Initializes a context.
	
	The context is used for selecting and initializing an appropriate backend and to represent the backend at a more global level than that of an individual
	device. There is one context to many devices, and a device is created from a context. A context is required to enumerate devices.
	
	
	Parameters
	----------
	backends (in, optional)
	    A list of backends to try initializing, in priority order. Can be NULL, in which case it uses default priority order.
	
	backendCount (in, optional)
	    The number of items in `backend`. Ignored if `backend` is NULL.
	
	pConfig (in, optional)
	    The context configuration.
	
	pContext (in)
	    A pointer to the context object being initialized.
	
	
	Return Value
	------------
	MA_SUCCESS if successful; any other error code otherwise.
	
	
	Thread Safety
	-------------
	Unsafe. Do not call this function across multiple threads as some backends read and write to global state.
	
	
	Remarks
	-------
	When `backends` is NULL, the default priority order will be used. Below is a list of backends in priority order:
	
	    |-------------|-----------------------|--------------------------------------------------------|
	    | Name        | Enum Name             | Supported Operating Systems                            |
	    |-------------|-----------------------|--------------------------------------------------------|
	    | WASAPI      | ma_backend_wasapi     | Windows Vista+                                         |
	    | DirectSound | ma_backend_dsound     | Windows XP+                                            |
	    | WinMM       | ma_backend_winmm      | Windows XP+ (may work on older versions, but untested) |
	    | Core Audio  | ma_backend_coreaudio  | macOS, iOS                                             |
	    | ALSA        | ma_backend_alsa       | Linux                                                  |
	    | PulseAudio  | ma_backend_pulseaudio | Cross Platform (disabled on Windows, BSD and Android)  |
	    | JACK        | ma_backend_jack       | Cross Platform (disabled on BSD and Android)           |
	    | sndio       | ma_backend_sndio      | OpenBSD                                                |
	    | audio(4)    | ma_backend_audio4     | NetBSD, OpenBSD                                        |
	    | OSS         | ma_backend_oss        | FreeBSD                                                |
	    | AAudio      | ma_backend_aaudio     | Android 8+                                             |
	    | OpenSL|ES   | ma_backend_opensl     | Android (API level 16+)                                |
	    | Web Audio   | ma_backend_webaudio   | Web (via Emscripten)                                   |
	    | Null        | ma_backend_null       | Cross Platform (not used on Web)                       |
	    |-------------|-----------------------|--------------------------------------------------------|
	
	The context can be configured via the `pConfig` argument. The config object is initialized with `ma_context_config_init()`. Individual configuration settings
	can then be set directly on the structure. Below are the members of the `ma_context_config` object.
	
	    pLog
	        A pointer to the `ma_log` to post log messages to. Can be NULL if the application does not
	        require logging. See the `ma_log` API for details on how to use the logging system.
	
	    threadPriority
	        The desired priority to use for the audio thread. Allowable values include the following:
	
	        |--------------------------------------|
	        | Thread Priority                      |
	        |--------------------------------------|
	        | ma_thread_priority_idle              |
	        | ma_thread_priority_lowest            |
	        | ma_thread_priority_low               |
	        | ma_thread_priority_normal            |
	        | ma_thread_priority_high              |
	        | ma_thread_priority_highest (default) |
	        | ma_thread_priority_realtime          |
	        | ma_thread_priority_default           |
	        |--------------------------------------|
	
	    threadStackSize
	        The desired size of the stack for the audio thread. Defaults to the operating system's default.
	
	    pUserData
	        A pointer to application-defined data. This can be accessed from the context object directly such as `context.pUserData`.
	
	    allocationCallbacks
	        Structure containing custom allocation callbacks. Leaving this at defaults will cause it to use MA_MALLOC, MA_REALLOC and MA_FREE. These allocation
	        callbacks will be used for anything tied to the context, including devices.
	
	    alsa.useVerboseDeviceEnumeration
	        ALSA will typically enumerate many different devices which can be intrusive and not user-friendly. To combat this, miniaudio will enumerate only unique
	        card/device pairs by default. The problem with this is that you lose a bit of flexibility and control. Setting alsa.useVerboseDeviceEnumeration makes
	        it so the ALSA backend includes all devices. Defaults to false.
	
	    pulse.pApplicationName
	        PulseAudio only. The application name to use when initializing the PulseAudio context with `pa_context_new()`.
	
	    pulse.pServerName
	        PulseAudio only. The name of the server to connect to with `pa_context_connect()`.
	
	    pulse.tryAutoSpawn
	        PulseAudio only. Whether or not to try automatically starting the PulseAudio daemon. Defaults to false. If you set this to true, keep in mind that
	        miniaudio uses a trial and error method to find the most appropriate backend, and this will result in the PulseAudio daemon starting which may be
	        intrusive for the end user.
	
	    coreaudio.sessionCategory
	        iOS only. The session category to use for the shared AudioSession instance. Below is a list of allowable values and their Core Audio equivalents.
	
	        |-----------------------------------------|-------------------------------------|
	        | miniaudio Token                         | Core Audio Token                    |
	        |-----------------------------------------|-------------------------------------|
	        | ma_ios_session_category_ambient         | AVAudioSessionCategoryAmbient       |
	        | ma_ios_session_category_solo_ambient    | AVAudioSessionCategorySoloAmbient   |
	        | ma_ios_session_category_playback        | AVAudioSessionCategoryPlayback      |
	        | ma_ios_session_category_record          | AVAudioSessionCategoryRecord        |
	        | ma_ios_session_category_play_and_record | AVAudioSessionCategoryPlayAndRecord |
	        | ma_ios_session_category_multi_route     | AVAudioSessionCategoryMultiRoute    |
	        | ma_ios_session_category_none            | AVAudioSessionCategoryAmbient       |
	        | ma_ios_session_category_default         | AVAudioSessionCategoryAmbient       |
	        |-----------------------------------------|-------------------------------------|
	
	    coreaudio.sessionCategoryOptions
	        iOS only. Session category options to use with the shared AudioSession instance. Below is a list of allowable values and their Core Audio equivalents.
	
	        |---------------------------------------------------------------------------|------------------------------------------------------------------|
	        | miniaudio Token                                                           | Core Audio Token                                                 |
	        |---------------------------------------------------------------------------|------------------------------------------------------------------|
	        | ma_ios_session_category_option_mix_with_others                            | AVAudioSessionCategoryOptionMixWithOthers                        |
	        | ma_ios_session_category_option_duck_others                                | AVAudioSessionCategoryOptionDuckOthers                           |
	        | ma_ios_session_category_option_allow_bluetooth                            | AVAudioSessionCategoryOptionAllowBluetooth                       |
	        | ma_ios_session_category_option_default_to_speaker                         | AVAudioSessionCategoryOptionDefaultToSpeaker                     |
	        | ma_ios_session_category_option_interrupt_spoken_audio_and_mix_with_others | AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers |
	        | ma_ios_session_category_option_allow_bluetooth_a2dp                       | AVAudioSessionCategoryOptionAllowBluetoothA2DP                   |
	        | ma_ios_session_category_option_allow_air_play                             | AVAudioSessionCategoryOptionAllowAirPlay                         |
	        |---------------------------------------------------------------------------|------------------------------------------------------------------|
	
	    coreaudio.noAudioSessionActivate
	        iOS only. When set to true, does not perform an explicit [[AVAudioSession sharedInstace] setActive:true] on initialization.
	
	    coreaudio.noAudioSessionDeactivate
	        iOS only. When set to true, does not perform an explicit [[AVAudioSession sharedInstace] setActive:false] on uninitialization.
	
	    jack.pClientName
	        The name of the client to pass to `jack_client_open()`.
	
	    jack.tryStartServer
	        Whether or not to try auto-starting the JACK server. Defaults to false.
	
	
	It is recommended that only a single context is active at any given time because it's a bulky data structure which performs run-time linking for the
	relevant backends every time it's initialized.
	
	The location of the context cannot change throughout it's lifetime. Consider allocating the `ma_context` object with `malloc()` if this is an issue. The
	reason for this is that a pointer to the context is stored in the `ma_device` structure.
	
	
	Example 1 - Default Initialization
	----------------------------------
	The example below shows how to initialize the context using the default configuration.
	
	```c
	ma_context context;
	ma_result result = ma_context_init(NULL, 0, NULL, &context);
	if (result != MA_SUCCESS) {
	    // Error.
	}
	```
	
	
	Example 2 - Custom Configuration
	--------------------------------
	The example below shows how to initialize the context using custom backend priorities and a custom configuration. In this hypothetical example, the program
	wants to prioritize ALSA over PulseAudio on Linux. They also want to avoid using the WinMM backend on Windows because it's latency is too high. They also
	want an error to be returned if no valid backend is available which they achieve by excluding the Null backend.
	
	For the configuration, the program wants to capture any log messages so they can, for example, route it to a log file and user interface.
	
	```c
	ma_backend backends[] = {
	    ma_backend_alsa,
	    ma_backend_pulseaudio,
	    ma_backend_wasapi,
	    ma_backend_dsound
	};
	
	ma_log log;
	ma_log_init(&log);
	ma_log_register_callback(&log, ma_log_callback_init(my_log_callbac, pMyLogUserData));
	
	ma_context_config config = ma_context_config_init();
	config.pLog = &log; // Specify a custom log object in the config so any logs that are posted from ma_context_init() are captured.
	
	ma_context context;
	ma_result result = ma_context_init(backends, sizeof(backends)/sizeof(backends[0]), &config, &context);
	if (result != MA_SUCCESS) {
	    // Error.
	    if (result == MA_NO_BACKEND) {
	        // Couldn't find an appropriate backend.
	    }
	}
	
	// You could also attach a log callback post-initialization:
	ma_log_register_callback(ma_context_get_log(&context), ma_log_callback_init(my_log_callback, pMyLogUserData));
	```
	
	
	See Also
	--------
	ma_context_config_init()
	ma_context_uninit()
	*/
	context_init :: proc(backends: ^backend, backendCount: uint32, pConfig: ^context_config, pContext: ^context_) -> result ---
	/*
	Uninitializes a context.
	
	
	Return Value
	------------
	MA_SUCCESS if successful; any other error code otherwise.
	
	
	Thread Safety
	-------------
	Unsafe. Do not call this function across multiple threads as some backends read and write to global state.
	
	
	Remarks
	-------
	Results are undefined if you call this while any device created by this context is still active.
	
	
	See Also
	--------
	ma_context_init()
	*/
	context_uninit :: proc(pContext: ^context_) -> result ---
	/*
	Retrieves the size of the ma_context object.
	
	This is mainly for the purpose of bindings to know how much memory to allocate.
	*/
	context_sizeof :: proc() -> uint ---
	/*
	Retrieves a pointer to the log object associated with this context.
	
	
	Remarks
	-------
	Pass the returned pointer to `ma_log_post()`, `ma_log_postv()` or `ma_log_postf()` to post a log
	message.
	
	You can attach your own logging callback to the log with `ma_log_register_callback()`
	
	
	Return Value
	------------
	A pointer to the `ma_log` object that the context uses to post log messages. If some error occurs,
	NULL will be returned.
	*/
	context_get_log :: proc(pContext: ^context_) -> ^log ---
	/*
	Enumerates over every device (both playback and capture).
	
	This is a lower-level enumeration function to the easier to use `ma_context_get_devices()`. Use `ma_context_enumerate_devices()` if you would rather not incur
	an internal heap allocation, or it simply suits your code better.
	
	Note that this only retrieves the ID and name/description of the device. The reason for only retrieving basic information is that it would otherwise require
	opening the backend device in order to probe it for more detailed information which can be inefficient. Consider using `ma_context_get_device_info()` for this,
	but don't call it from within the enumeration callback.
	
	Returning false from the callback will stop enumeration. Returning true will continue enumeration.
	
	
	Parameters
	----------
	pContext (in)
	    A pointer to the context performing the enumeration.
	
	callback (in)
	    The callback to fire for each enumerated device.
	
	pUserData (in)
	    A pointer to application-defined data passed to the callback.
	
	
	Return Value
	------------
	MA_SUCCESS if successful; any other error code otherwise.
	
	
	Thread Safety
	-------------
	Safe. This is guarded using a simple mutex lock.
	
	
	Remarks
	-------
	Do _not_ assume the first enumerated device of a given type is the default device.
	
	Some backends and platforms may only support default playback and capture devices.
	
	In general, you should not do anything complicated from within the callback. In particular, do not try initializing a device from within the callback. Also,
	do not try to call `ma_context_get_device_info()` from within the callback.
	
	Consider using `ma_context_get_devices()` for a simpler and safer API, albeit at the expense of an internal heap allocation.
	
	
	Example 1 - Simple Enumeration
	------------------------------
	ma_bool32 ma_device_enum_callback(ma_context* pContext, ma_device_type deviceType, const ma_device_info* pInfo, void* pUserData)
	{
	    printf("Device Name: %s\n", pInfo->name);
	    return MA_TRUE;
	}
	
	ma_result result = ma_context_enumerate_devices(&context, my_device_enum_callback, pMyUserData);
	if (result != MA_SUCCESS) {
	    // Error.
	}
	
	
	See Also
	--------
	ma_context_get_devices()
	*/
	context_enumerate_devices :: proc(pContext: ^context_, callback: enum_devices_callback_proc, pUserData: rawptr) -> result ---
	/*
	Retrieves basic information about every active playback and/or capture device.
	
	This function will allocate memory internally for the device lists and return a pointer to them through the `ppPlaybackDeviceInfos` and `ppCaptureDeviceInfos`
	parameters. If you do not want to incur the overhead of these allocations consider using `ma_context_enumerate_devices()` which will instead use a callback.
	
	Note that this only retrieves the ID and name/description of the device. The reason for only retrieving basic information is that it would otherwise require
	opening the backend device in order to probe it for more detailed information which can be inefficient. Consider using `ma_context_get_device_info()` for this,
	but don't call it from within the enumeration callback.
	
	
	Parameters
	----------
	pContext (in)
	    A pointer to the context performing the enumeration.
	
	ppPlaybackDeviceInfos (out)
	    A pointer to a pointer that will receive the address of a buffer containing the list of `ma_device_info` structures for playback devices.
	
	pPlaybackDeviceCount (out)
	    A pointer to an unsigned integer that will receive the number of playback devices.
	
	ppCaptureDeviceInfos (out)
	    A pointer to a pointer that will receive the address of a buffer containing the list of `ma_device_info` structures for capture devices.
	
	pCaptureDeviceCount (out)
	    A pointer to an unsigned integer that will receive the number of capture devices.
	
	
	Return Value
	------------
	MA_SUCCESS if successful; any other error code otherwise.
	
	
	Thread Safety
	-------------
	Unsafe. Since each call to this function invalidates the pointers from the previous call, you should not be calling this simultaneously across multiple
	threads. Instead, you need to make a copy of the returned data with your own higher level synchronization.
	
	
	Remarks
	-------
	It is _not_ safe to assume the first device in the list is the default device.
	
	You can pass in NULL for the playback or capture lists in which case they'll be ignored.
	
	The returned pointers will become invalid upon the next call this this function, or when the context is uninitialized. Do not free the returned pointers.
	
	
	See Also
	--------
	ma_context_enumerate_devices()
	*/
	context_get_devices :: proc(pContext: ^context_, ppPlaybackDeviceInfos: ^^device_info, pPlaybackDeviceCount: ^uint32, ppCaptureDeviceInfos: ^^device_info, pCaptureDeviceCount: ^uint32) -> result ---
	/*
	Retrieves information about a device of the given type, with the specified ID and share mode.
	
	
	Parameters
	----------
	pContext (in)
	    A pointer to the context performing the query.
	
	deviceType (in)
	    The type of the device being queried. Must be either `ma_device_type_playback` or `ma_device_type_capture`.
	
	pDeviceID (in)
	    The ID of the device being queried.
	
	pDeviceInfo (out)
	    A pointer to the `ma_device_info` structure that will receive the device information.
	
	
	Return Value
	------------
	MA_SUCCESS if successful; any other error code otherwise.
	
	
	Thread Safety
	-------------
	Safe. This is guarded using a simple mutex lock.
	
	
	Remarks
	-------
	Do _not_ call this from within the `ma_context_enumerate_devices()` callback.
	
	It's possible for a device to have different information and capabilities depending on whether or not it's opened in shared or exclusive mode. For example, in
	shared mode, WASAPI always uses floating point samples for mixing, but in exclusive mode it can be anything. Therefore, this function allows you to specify
	which share mode you want information for. Note that not all backends and devices support shared or exclusive mode, in which case this function will fail if
	the requested share mode is unsupported.
	
	This leaves pDeviceInfo unmodified in the result of an error.
	*/
	context_get_device_info :: proc(pContext: ^context_, deviceType: device_type, pDeviceID: ^device_id, pDeviceInfo: ^device_info) -> result ---
	/*
	Determines if the given context supports loopback mode.
	
	
	Parameters
	----------
	pContext (in)
	    A pointer to the context getting queried.
	
	
	Return Value
	------------
	MA_TRUE if the context supports loopback mode; MA_FALSE otherwise.
	*/
	context_is_loopback_supported :: proc(pContext: ^context_) -> bool32 ---
	/*
	Initializes a device config with default settings.
	
	
	Parameters
	----------
	deviceType (in)
	    The type of the device this config is being initialized for. This must set to one of the following:
	
	    |-------------------------|
	    | Device Type             |
	    |-------------------------|
	    | ma_device_type_playback |
	    | ma_device_type_capture  |
	    | ma_device_type_duplex   |
	    | ma_device_type_loopback |
	    |-------------------------|
	
	
	Return Value
	------------
	A new device config object with default settings. You will typically want to adjust the config after this function returns. See remarks.
	
	
	Thread Safety
	-------------
	Safe.
	
	
	Callback Safety
	---------------
	Safe, but don't try initializing a device in a callback.
	
	
	Remarks
	-------
	The returned config will be initialized to defaults. You will normally want to customize a few variables before initializing the device. See Example 1 for a
	typical configuration which sets the sample format, channel count, sample rate, data callback and user data. These are usually things you will want to change
	before initializing the device.
	
	See `ma_device_init()` for details on specific configuration options.
	
	
	Example 1 - Simple Configuration
	--------------------------------
	The example below is what a program will typically want to configure for each device at a minimum. Notice how `ma_device_config_init()` is called first, and
	then the returned object is modified directly. This is important because it ensures that your program continues to work as new configuration options are added
	to the `ma_device_config` structure.
	
	```c
	ma_device_config config = ma_device_config_init(ma_device_type_playback);
	config.playback.format   = ma_format_f32;
	config.playback.channels = 2;
	config.sampleRate        = 48000;
	config.dataCallback      = ma_data_callback;
	config.pUserData         = pMyUserData;
	```
	
	
	See Also
	--------
	ma_device_init()
	ma_device_init_ex()
	*/
	device_config_init :: proc(deviceType: device_type) -> device_config ---
	/*
	Initializes a device.
	
	A device represents a physical audio device. The idea is you send or receive audio data from the device to either play it back through a speaker, or capture it
	from a microphone. Whether or not you should send or receive data from the device (or both) depends on the type of device you are initializing which can be
	playback, capture, full-duplex or loopback. (Note that loopback mode is only supported on select backends.) Sending and receiving audio data to and from the
	device is done via a callback which is fired by miniaudio at periodic time intervals.
	
	The frequency at which data is delivered to and from a device depends on the size of its period. The size of the period can be defined in terms of PCM frames
	or milliseconds, whichever is more convenient. Generally speaking, the smaller the period, the lower the latency at the expense of higher CPU usage and
	increased risk of glitching due to the more frequent and granular data deliver intervals. The size of a period will depend on your requirements, but
	miniaudio's defaults should work fine for most scenarios. If you're building a game you should leave this fairly small, whereas if you're building a simple
	media player you can make it larger. Note that the period size you request is actually just a hint - miniaudio will tell the backend what you want, but the
	backend is ultimately responsible for what it gives you. You cannot assume you will get exactly what you ask for.
	
	When delivering data to and from a device you need to make sure it's in the correct format which you can set through the device configuration. You just set the
	format that you want to use and miniaudio will perform all of the necessary conversion for you internally. When delivering data to and from the callback you
	can assume the format is the same as what you requested when you initialized the device. See Remarks for more details on miniaudio's data conversion pipeline.
	
	
	Parameters
	----------
	pContext (in, optional)
	    A pointer to the context that owns the device. This can be null, in which case it creates a default context internally.
	
	pConfig (in)
	    A pointer to the device configuration. Cannot be null. See remarks for details.
	
	pDevice (out)
	    A pointer to the device object being initialized.
	
	
	Return Value
	------------
	MA_SUCCESS if successful; any other error code otherwise.
	
	
	Thread Safety
	-------------
	Unsafe. It is not safe to call this function simultaneously for different devices because some backends depend on and mutate global state. The same applies to
	calling this at the same time as `ma_device_uninit()`.
	
	
	Callback Safety
	---------------
	Unsafe. It is not safe to call this inside any callback.
	
	
	Remarks
	-------
	Setting `pContext` to NULL will result in miniaudio creating a default context internally and is equivalent to passing in a context initialized like so:
	
	    ```c
	    ma_context_init(NULL, 0, NULL, &context);
	    ```
	
	Do not set `pContext` to NULL if you are needing to open multiple devices. You can, however, use NULL when initializing the first device, and then use
	device.pContext for the initialization of other devices.
	
	The device can be configured via the `pConfig` argument. The config object is initialized with `ma_device_config_init()`. Individual configuration settings can
	then be set directly on the structure. Below are the members of the `ma_device_config` object.
	
	    deviceType
	        Must be `ma_device_type_playback`, `ma_device_type_capture`, `ma_device_type_duplex` of `ma_device_type_loopback`.
	
	    sampleRate
	        The sample rate, in hertz. The most common sample rates are 48000 and 44100. Setting this to 0 will use the device's native sample rate.
	
	    periodSizeInFrames
	        The desired size of a period in PCM frames. If this is 0, `periodSizeInMilliseconds` will be used instead. If both are 0 the default buffer size will
	        be used depending on the selected performance profile. This value affects latency. See below for details.
	
	    periodSizeInMilliseconds
	        The desired size of a period in milliseconds. If this is 0, `periodSizeInFrames` will be used instead. If both are 0 the default buffer size will be
	        used depending on the selected performance profile. The value affects latency. See below for details.
	
	    periods
	        The number of periods making up the device's entire buffer. The total buffer size is `periodSizeInFrames` or `periodSizeInMilliseconds` multiplied by
	        this value. This is just a hint as backends will be the ones who ultimately decide how your periods will be configured.
	
	    performanceProfile
	        A hint to miniaudio as to the performance requirements of your program. Can be either `ma_performance_profile_low_latency` (default) or
	        `ma_performance_profile_conservative`. This mainly affects the size of default buffers and can usually be left at its default value.
	
	    noPreSilencedOutputBuffer
	        When set to true, the contents of the output buffer passed into the data callback will be left undefined. When set to false (default), the contents of
	        the output buffer will be cleared the zero. You can use this to avoid the overhead of zeroing out the buffer if you can guarantee that your data
	        callback will write to every sample in the output buffer, or if you are doing your own clearing.
	
	    noClip
	        When set to true, the contents of the output buffer are left alone after returning and it will be left up to the backend itself to decide whether or
	        not to clip. When set to false (default), the contents of the output buffer passed into the data callback will be clipped after returning. This only
	        applies when the playback sample format is f32.
	
	    noDisableDenormals
	        By default, miniaudio will disable denormals when the data callback is called. Setting this to true will prevent the disabling of denormals.
	
	    noFixedSizedCallback
	        Allows miniaudio to fire the data callback with any frame count. When this is set to false (the default), the data callback will be fired with a
	        consistent frame count as specified by `periodSizeInFrames` or `periodSizeInMilliseconds`. When set to true, miniaudio will fire the callback with
	        whatever the backend requests, which could be anything.
	
	    dataCallback
	        The callback to fire whenever data is ready to be delivered to or from the device.
	
	    notificationCallback
	        The callback to fire when something has changed with the device, such as whether or not it has been started or stopped.
	
	    pUserData
	        The user data pointer to use with the device. You can access this directly from the device object like `device.pUserData`.
	
	    resampling.algorithm
	        The resampling algorithm to use when miniaudio needs to perform resampling between the rate specified by `sampleRate` and the device's native rate. The
	        default value is `ma_resample_algorithm_linear`, and the quality can be configured with `resampling.linear.lpfOrder`.
	
	    resampling.pBackendVTable
	        A pointer to an optional vtable that can be used for plugging in a custom resampler.
	
	    resampling.pBackendUserData
	        A pointer that will passed to callbacks in pBackendVTable.
	
	    resampling.linear.lpfOrder
	        The linear resampler applies a low-pass filter as part of its processing for anti-aliasing. This setting controls the order of the filter. The higher
	        the value, the better the quality, in general. Setting this to 0 will disable low-pass filtering altogether. The maximum value is
	        `MA_MAX_FILTER_ORDER`. The default value is `min(4, MA_MAX_FILTER_ORDER)`.
	
	    playback.pDeviceID
	        A pointer to a `ma_device_id` structure containing the ID of the playback device to initialize. Setting this NULL (default) will use the system's
	        default playback device. Retrieve the device ID from the `ma_device_info` structure, which can be retrieved using device enumeration.
	
	    playback.format
	        The sample format to use for playback. When set to `ma_format_unknown` the device's native format will be used. This can be retrieved after
	        initialization from the device object directly with `device.playback.format`.
	
	    playback.channels
	        The number of channels to use for playback. When set to 0 the device's native channel count will be used. This can be retrieved after initialization
	        from the device object directly with `device.playback.channels`.
	
	    playback.pChannelMap
	        The channel map to use for playback. When left empty, the device's native channel map will be used. This can be retrieved after initialization from the
	        device object direct with `device.playback.pChannelMap`. When set, the buffer should contain `channels` items.
	
	    playback.shareMode
	        The preferred share mode to use for playback. Can be either `ma_share_mode_shared` (default) or `ma_share_mode_exclusive`. Note that if you specify
	        exclusive mode, but it's not supported by the backend, initialization will fail. You can then fall back to shared mode if desired by changing this to
	        ma_share_mode_shared and reinitializing.
	
	    capture.pDeviceID
	        A pointer to a `ma_device_id` structure containing the ID of the capture device to initialize. Setting this NULL (default) will use the system's
	        default capture device. Retrieve the device ID from the `ma_device_info` structure, which can be retrieved using device enumeration.
	
	    capture.format
	        The sample format to use for capture. When set to `ma_format_unknown` the device's native format will be used. This can be retrieved after
	        initialization from the device object directly with `device.capture.format`.
	
	    capture.channels
	        The number of channels to use for capture. When set to 0 the device's native channel count will be used. This can be retrieved after initialization
	        from the device object directly with `device.capture.channels`.
	
	    capture.pChannelMap
	        The channel map to use for capture. When left empty, the device's native channel map will be used. This can be retrieved after initialization from the
	        device object direct with `device.capture.pChannelMap`. When set, the buffer should contain `channels` items.
	
	    capture.shareMode
	        The preferred share mode to use for capture. Can be either `ma_share_mode_shared` (default) or `ma_share_mode_exclusive`. Note that if you specify
	        exclusive mode, but it's not supported by the backend, initialization will fail. You can then fall back to shared mode if desired by changing this to
	        ma_share_mode_shared and reinitializing.
	
	    wasapi.noAutoConvertSRC
	        WASAPI only. When set to true, disables WASAPI's automatic resampling and forces the use of miniaudio's resampler. Defaults to false.
	
	    wasapi.noDefaultQualitySRC
	        WASAPI only. Only used when `wasapi.noAutoConvertSRC` is set to false. When set to true, disables the use of `AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY`.
	        You should usually leave this set to false, which is the default.
	
	    wasapi.noAutoStreamRouting
	        WASAPI only. When set to true, disables automatic stream routing on the WASAPI backend. Defaults to false.
	
	    wasapi.noHardwareOffloading
	        WASAPI only. When set to true, disables the use of WASAPI's hardware offloading feature. Defaults to false.
	
	    alsa.noMMap
	        ALSA only. When set to true, disables MMap mode. Defaults to false.
	
	    alsa.noAutoFormat
	        ALSA only. When set to true, disables ALSA's automatic format conversion by including the SND_PCM_NO_AUTO_FORMAT flag. Defaults to false.
	
	    alsa.noAutoChannels
	        ALSA only. When set to true, disables ALSA's automatic channel conversion by including the SND_PCM_NO_AUTO_CHANNELS flag. Defaults to false.
	
	    alsa.noAutoResample
	        ALSA only. When set to true, disables ALSA's automatic resampling by including the SND_PCM_NO_AUTO_RESAMPLE flag. Defaults to false.
	
	    pulse.pStreamNamePlayback
	        PulseAudio only. Sets the stream name for playback.
	
	    pulse.pStreamNameCapture
	        PulseAudio only. Sets the stream name for capture.
	
	    pulse.channelMap
	        PulseAudio only. Sets the channel map that is requested from PulseAudio. See MA_PA_CHANNEL_MAP_* constants. Defaults to MA_PA_CHANNEL_MAP_AIFF.
	
	    coreaudio.allowNominalSampleRateChange
	        Core Audio only. Desktop only. When enabled, allows the sample rate of the device to be changed at the operating system level. This
	        is disabled by default in order to prevent intrusive changes to the user's system. This is useful if you want to use a sample rate
	        that is known to be natively supported by the hardware thereby avoiding the cost of resampling. When set to true, miniaudio will
	        find the closest match between the sample rate requested in the device config and the sample rates natively supported by the
	        hardware. When set to false, the sample rate currently set by the operating system will always be used.
	
	    opensl.streamType
	        OpenSL only. Explicitly sets the stream type. If left unset (`ma_opensl_stream_type_default`), the
	        stream type will be left unset. Think of this as the type of audio you're playing.
	
	    opensl.recordingPreset
	        OpenSL only. Explicitly sets the type of recording your program will be doing. When left
	        unset, the recording preset will be left unchanged.
	
	    aaudio.usage
	        AAudio only. Explicitly sets the nature of the audio the program will be consuming. When
	        left unset, the usage will be left unchanged.
	
	    aaudio.contentType
	        AAudio only. Sets the content type. When left unset, the content type will be left unchanged.
	
	    aaudio.inputPreset
	        AAudio only. Explicitly sets the type of recording your program will be doing. When left
	        unset, the input preset will be left unchanged.
	
	    aaudio.noAutoStartAfterReroute
	        AAudio only. Controls whether or not the device should be automatically restarted after a
	        stream reroute. When set to false (default) the device will be restarted automatically;
	        otherwise the device will be stopped.
	
	
	Once initialized, the device's config is immutable. If you need to change the config you will need to initialize a new device.
	
	After initializing the device it will be in a stopped state. To start it, use `ma_device_start()`.
	
	If both `periodSizeInFrames` and `periodSizeInMilliseconds` are set to zero, it will default to `MA_DEFAULT_PERIOD_SIZE_IN_MILLISECONDS_LOW_LATENCY` or
	`MA_DEFAULT_PERIOD_SIZE_IN_MILLISECONDS_CONSERVATIVE`, depending on whether or not `performanceProfile` is set to `ma_performance_profile_low_latency` or
	`ma_performance_profile_conservative`.
	
	If you request exclusive mode and the backend does not support it an error will be returned. For robustness, you may want to first try initializing the device
	in exclusive mode, and then fall back to shared mode if required. Alternatively you can just request shared mode (the default if you leave it unset in the
	config) which is the most reliable option. Some backends do not have a practical way of choosing whether or not the device should be exclusive or not (ALSA,
	for example) in which case it just acts as a hint. Unless you have special requirements you should try avoiding exclusive mode as it's intrusive to the user.
	Starting with Windows 10, miniaudio will use low-latency shared mode where possible which may make exclusive mode unnecessary.
	
	When sending or receiving data to/from a device, miniaudio will internally perform a format conversion to convert between the format specified by the config
	and the format used internally by the backend. If you pass in 0 for the sample format, channel count, sample rate _and_ channel map, data transmission will run
	on an optimized pass-through fast path. You can retrieve the format, channel count and sample rate by inspecting the `playback/capture.format`,
	`playback/capture.channels` and `sampleRate` members of the device object.
	
	When compiling for UWP you must ensure you call this function on the main UI thread because the operating system may need to present the user with a message
	asking for permissions. Please refer to the official documentation for ActivateAudioInterfaceAsync() for more information.
	
	ALSA Specific: When initializing the default device, requesting shared mode will try using the "dmix" device for playback and the "dsnoop" device for capture.
	If these fail it will try falling back to the "hw" device.
	
	
	Example 1 - Simple Initialization
	---------------------------------
	This example shows how to initialize a simple playback device using a standard configuration. If you are just needing to do simple playback from the default
	playback device this is usually all you need.
	
	```c
	ma_device_config config = ma_device_config_init(ma_device_type_playback);
	config.playback.format   = ma_format_f32;
	config.playback.channels = 2;
	config.sampleRate        = 48000;
	config.dataCallback      = ma_data_callback;
	config.pMyUserData       = pMyUserData;
	
	ma_device device;
	ma_result result = ma_device_init(NULL, &config, &device);
	if (result != MA_SUCCESS) {
	    // Error
	}
	```
	
	
	Example 2 - Advanced Initialization
	-----------------------------------
	This example shows how you might do some more advanced initialization. In this hypothetical example we want to control the latency by setting the buffer size
	and period count. We also want to allow the user to be able to choose which device to output from which means we need a context so we can perform device
	enumeration.
	
	```c
	ma_context context;
	ma_result result = ma_context_init(NULL, 0, NULL, &context);
	if (result != MA_SUCCESS) {
	    // Error
	}
	
	ma_device_info* pPlaybackDeviceInfos;
	ma_uint32 playbackDeviceCount;
	result = ma_context_get_devices(&context, &pPlaybackDeviceInfos, &playbackDeviceCount, NULL, NULL);
	if (result != MA_SUCCESS) {
	    // Error
	}
	
	// ... choose a device from pPlaybackDeviceInfos ...
	
	ma_device_config config = ma_device_config_init(ma_device_type_playback);
	config.playback.pDeviceID       = pMyChosenDeviceID;    // <-- Get this from the `id` member of one of the `ma_device_info` objects returned by ma_context_get_devices().
	config.playback.format          = ma_format_f32;
	config.playback.channels        = 2;
	config.sampleRate               = 48000;
	config.dataCallback             = ma_data_callback;
	config.pUserData                = pMyUserData;
	config.periodSizeInMilliseconds = 10;
	config.periods                  = 3;
	
	ma_device device;
	result = ma_device_init(&context, &config, &device);
	if (result != MA_SUCCESS) {
	    // Error
	}
	```
	
	
	See Also
	--------
	ma_device_config_init()
	ma_device_uninit()
	ma_device_start()
	ma_context_init()
	ma_context_get_devices()
	ma_context_enumerate_devices()
	*/
	device_init :: proc(pContext: ^context_, pConfig: ^device_config, pDevice: ^device) -> result ---
	/*
	Initializes a device without a context, with extra parameters for controlling the configuration of the internal self-managed context.
	
	This is the same as `ma_device_init()`, only instead of a context being passed in, the parameters from `ma_context_init()` are passed in instead. This function
	allows you to configure the internally created context.
	
	
	Parameters
	----------
	backends (in, optional)
	    A list of backends to try initializing, in priority order. Can be NULL, in which case it uses default priority order.
	
	backendCount (in, optional)
	    The number of items in `backend`. Ignored if `backend` is NULL.
	
	pContextConfig (in, optional)
	    The context configuration.
	
	pConfig (in)
	    A pointer to the device configuration. Cannot be null. See remarks for details.
	
	pDevice (out)
	    A pointer to the device object being initialized.
	
	
	Return Value
	------------
	MA_SUCCESS if successful; any other error code otherwise.
	
	
	Thread Safety
	-------------
	Unsafe. It is not safe to call this function simultaneously for different devices because some backends depend on and mutate global state. The same applies to
	calling this at the same time as `ma_device_uninit()`.
	
	
	Callback Safety
	---------------
	Unsafe. It is not safe to call this inside any callback.
	
	
	Remarks
	-------
	You only need to use this function if you want to configure the context differently to its defaults. You should never use this function if you want to manage
	your own context.
	
	See the documentation for `ma_context_init()` for information on the different context configuration options.
	
	
	See Also
	--------
	ma_device_init()
	ma_device_uninit()
	ma_device_config_init()
	ma_context_init()
	*/
	device_init_ex :: proc(backends: ^backend, backendCount: uint32, pContextConfig: ^context_config, pConfig: ^device_config, pDevice: ^device) -> result ---
	/*
	Uninitializes a device.
	
	This will explicitly stop the device. You do not need to call `ma_device_stop()` beforehand, but it's harmless if you do.
	
	
	Parameters
	----------
	pDevice (in)
	    A pointer to the device to stop.
	
	
	Return Value
	------------
	Nothing
	
	
	Thread Safety
	-------------
	Unsafe. As soon as this API is called the device should be considered undefined.
	
	
	Callback Safety
	---------------
	Unsafe. It is not safe to call this inside any callback. Doing this will result in a deadlock.
	
	
	See Also
	--------
	ma_device_init()
	ma_device_stop()
	*/
	device_uninit :: proc(pDevice: ^device) ---
	/*
	Retrieves a pointer to the context that owns the given device.
	*/
	device_get_context :: proc(pDevice: ^device) -> ^context_ ---
	/*
	Helper function for retrieving the log object associated with the context that owns this device.
	*/
	device_get_log :: proc(pDevice: ^device) -> ^log ---
	/*
	Retrieves information about the device.
	
	
	Parameters
	----------
	pDevice (in)
	    A pointer to the device whose information is being retrieved.
	
	type (in)
	    The device type. This parameter is required for duplex devices. When retrieving device
	    information, you are doing so for an individual playback or capture device.
	
	pDeviceInfo (out)
	    A pointer to the `ma_device_info` that will receive the device information.
	
	
	Return Value
	------------
	MA_SUCCESS if successful; any other error code otherwise.
	
	
	Thread Safety
	-------------
	Unsafe. This should be considered unsafe because it may be calling into the backend which may or
	may not be safe.
	
	
	Callback Safety
	---------------
	Unsafe. You should avoid calling this in the data callback because it may call into the backend
	which may or may not be safe.
	*/
	device_get_info :: proc(pDevice: ^device, type: device_type, pDeviceInfo: ^device_info) -> result ---
	/*
	Retrieves the name of the device.
	
	
	Parameters
	----------
	pDevice (in)
	    A pointer to the device whose information is being retrieved.
	
	type (in)
	    The device type. This parameter is required for duplex devices. When retrieving device
	    information, you are doing so for an individual playback or capture device.
	
	pName (out)
	    A pointer to the buffer that will receive the name.
	
	nameCap (in)
	    The capacity of the output buffer, including space for the null terminator.
	
	pLengthNotIncludingNullTerminator (out, optional)
	    A pointer to the variable that will receive the length of the name, not including the null
	    terminator.
	
	
	Return Value
	------------
	MA_SUCCESS if successful; any other error code otherwise.
	
	
	Thread Safety
	-------------
	Unsafe. This should be considered unsafe because it may be calling into the backend which may or
	may not be safe.
	
	
	Callback Safety
	---------------
	Unsafe. You should avoid calling this in the data callback because it may call into the backend
	which may or may not be safe.
	
	
	Remarks
	-------
	If the name does not fully fit into the output buffer, it'll be truncated. You can pass in NULL to
	`pName` if you want to first get the length of the name for the purpose of memory allocation of the
	output buffer. Allocating a buffer of size `MA_MAX_DEVICE_NAME_LENGTH + 1` should be enough for
	most cases and will avoid the need for the inefficiency of calling this function twice.
	
	This is implemented in terms of `ma_device_get_info()`.
	*/
	device_get_name :: proc(pDevice: ^device, type: device_type, pName: ^u8, nameCap: uint, pLengthNotIncludingNullTerminator: ^uint) -> result ---
	/*
	Starts the device. For playback devices this begins playback. For capture devices it begins recording.
	
	Use `ma_device_stop()` to stop the device.
	
	
	Parameters
	----------
	pDevice (in)
	    A pointer to the device to start.
	
	
	Return Value
	------------
	MA_SUCCESS if successful; any other error code otherwise.
	
	
	Thread Safety
	-------------
	Safe. It's safe to call this from any thread with the exception of the callback thread.
	
	
	Callback Safety
	---------------
	Unsafe. It is not safe to call this inside any callback.
	
	
	Remarks
	-------
	For a playback device, this will retrieve an initial chunk of audio data from the client before returning. The reason for this is to ensure there is valid
	audio data in the buffer, which needs to be done before the device begins playback.
	
	This API waits until the backend device has been started for real by the worker thread. It also waits on a mutex for thread-safety.
	
	Do not call this in any callback.
	
	
	See Also
	--------
	ma_device_stop()
	*/
	device_start :: proc(pDevice: ^device) -> result ---
	/*
	Stops the device. For playback devices this stops playback. For capture devices it stops recording.
	
	Use `ma_device_start()` to start the device again.
	
	
	Parameters
	----------
	pDevice (in)
	    A pointer to the device to stop.
	
	
	Return Value
	------------
	MA_SUCCESS if successful; any other error code otherwise.
	
	
	Thread Safety
	-------------
	Safe. It's safe to call this from any thread with the exception of the callback thread.
	
	
	Callback Safety
	---------------
	Unsafe. It is not safe to call this inside any callback. Doing this will result in a deadlock.
	
	
	Remarks
	-------
	This API needs to wait on the worker thread to stop the backend device properly before returning. It also waits on a mutex for thread-safety. In addition, some
	backends need to wait for the device to finish playback/recording of the current fragment which can take some time (usually proportionate to the buffer size
	that was specified at initialization time).
	
	Backends are required to either pause the stream in-place or drain the buffer if pausing is not possible. The reason for this is that stopping the device and
	the resuming it with ma_device_start() (which you might do when your program loses focus) may result in a situation where those samples are never output to the
	speakers or received from the microphone which can in turn result in de-syncs.
	
	Do not call this in any callback.
	
	
	See Also
	--------
	ma_device_start()
	*/
	device_stop :: proc(pDevice: ^device) -> result ---
	/*
	Determines whether or not the device is started.
	
	
	Parameters
	----------
	pDevice (in)
	    A pointer to the device whose start state is being retrieved.
	
	
	Return Value
	------------
	True if the device is started, false otherwise.
	
	
	Thread Safety
	-------------
	Safe. If another thread calls `ma_device_start()` or `ma_device_stop()` at this same time as this function is called, there's a very small chance the return
	value will be out of sync.
	
	
	Callback Safety
	---------------
	Safe. This is implemented as a simple accessor.
	
	
	See Also
	--------
	ma_device_start()
	ma_device_stop()
	*/
	device_is_started :: proc(pDevice: ^device) -> bool32 ---
	/*
	Retrieves the state of the device.
	
	
	Parameters
	----------
	pDevice (in)
	    A pointer to the device whose state is being retrieved.
	
	
	Return Value
	------------
	The current state of the device. The return value will be one of the following:
	
	    +-------------------------------+------------------------------------------------------------------------------+
	    | ma_device_state_uninitialized | Will only be returned if the device is in the middle of initialization.      |
	    +-------------------------------+------------------------------------------------------------------------------+
	    | ma_device_state_stopped       | The device is stopped. The initial state of the device after initialization. |
	    +-------------------------------+------------------------------------------------------------------------------+
	    | ma_device_state_started       | The device started and requesting and/or delivering audio data.              |
	    +-------------------------------+------------------------------------------------------------------------------+
	    | ma_device_state_starting      | The device is in the process of starting.                                    |
	    +-------------------------------+------------------------------------------------------------------------------+
	    | ma_device_state_stopping      | The device is in the process of stopping.                                    |
	    +-------------------------------+------------------------------------------------------------------------------+
	
	
	Thread Safety
	-------------
	Safe. This is implemented as a simple accessor. Note that if the device is started or stopped at the same time as this function is called,
	there's a possibility the return value could be out of sync. See remarks.
	
	
	Callback Safety
	---------------
	Safe. This is implemented as a simple accessor.
	
	
	Remarks
	-------
	The general flow of a devices state goes like this:
	
	    ```
	    ma_device_init()  -> ma_device_state_uninitialized -> ma_device_state_stopped
	    ma_device_start() -> ma_device_state_starting      -> ma_device_state_started
	    ma_device_stop()  -> ma_device_state_stopping      -> ma_device_state_stopped
	    ```
	
	When the state of the device is changed with `ma_device_start()` or `ma_device_stop()` at this same time as this function is called, the
	value returned by this function could potentially be out of sync. If this is significant to your program you need to implement your own
	synchronization.
	*/
	device_get_state :: proc(pDevice: ^device) -> device_state ---
	/*
	Performs post backend initialization routines for setting up internal data conversion.
	
	This should be called whenever the backend is initialized. The only time this should be called from
	outside of miniaudio is if you're implementing a custom backend, and you would only do it if you
	are reinitializing the backend due to rerouting or reinitializing for some reason.
	
	
	Parameters
	----------
	pDevice [in]
	    A pointer to the device.
	
	deviceType [in]
	    The type of the device that was just reinitialized.
	
	pPlaybackDescriptor [in]
	    The descriptor of the playback device containing the internal data format and buffer sizes.
	
	pPlaybackDescriptor [in]
	    The descriptor of the capture device containing the internal data format and buffer sizes.
	
	
	Return Value
	------------
	MA_SUCCESS if successful; any other error otherwise.
	
	
	Thread Safety
	-------------
	Unsafe. This will be reinitializing internal data converters which may be in use by another thread.
	
	
	Callback Safety
	---------------
	Unsafe. This will be reinitializing internal data converters which may be in use by the callback.
	
	
	Remarks
	-------
	For a duplex device, you can call this for only one side of the system. This is why the deviceType
	is specified as a parameter rather than deriving it from the device.
	
	You do not need to call this manually unless you are doing a custom backend, in which case you need
	only do it if you're manually performing rerouting or reinitialization.
	*/
	device_post_init :: proc(pDevice: ^device, deviceType: device_type, pPlaybackDescriptor: ^device_descriptor, pCaptureDescriptor: ^device_descriptor) -> result ---
	/*
	Sets the master volume factor for the device.
	
	The volume factor must be between 0 (silence) and 1 (full volume). Use `ma_device_set_master_volume_db()` to use decibel notation, where 0 is full volume and
	values less than 0 decreases the volume.
	
	
	Parameters
	----------
	pDevice (in)
	    A pointer to the device whose volume is being set.
	
	volume (in)
	    The new volume factor. Must be >= 0.
	
	
	Return Value
	------------
	MA_SUCCESS if the volume was set successfully.
	MA_INVALID_ARGS if pDevice is NULL.
	MA_INVALID_ARGS if volume is negative.
	
	
	Thread Safety
	-------------
	Safe. This just sets a local member of the device object.
	
	
	Callback Safety
	---------------
	Safe. If you set the volume in the data callback, that data written to the output buffer will have the new volume applied.
	
	
	Remarks
	-------
	This applies the volume factor across all channels.
	
	This does not change the operating system's volume. It only affects the volume for the given `ma_device` object's audio stream.
	
	
	See Also
	--------
	ma_device_get_master_volume()
	ma_device_set_master_volume_db()
	ma_device_get_master_volume_db()
	*/
	device_set_master_volume :: proc(pDevice: ^device, volume: f32) -> result ---
	/*
	Retrieves the master volume factor for the device.
	
	
	Parameters
	----------
	pDevice (in)
	    A pointer to the device whose volume factor is being retrieved.
	
	pVolume (in)
	    A pointer to the variable that will receive the volume factor. The returned value will be in the range of [0, 1].
	
	
	Return Value
	------------
	MA_SUCCESS if successful.
	MA_INVALID_ARGS if pDevice is NULL.
	MA_INVALID_ARGS if pVolume is NULL.
	
	
	Thread Safety
	-------------
	Safe. This just a simple member retrieval.
	
	
	Callback Safety
	---------------
	Safe.
	
	
	Remarks
	-------
	If an error occurs, `*pVolume` will be set to 0.
	
	
	See Also
	--------
	ma_device_set_master_volume()
	ma_device_set_master_volume_gain_db()
	ma_device_get_master_volume_gain_db()
	*/
	device_get_master_volume :: proc(pDevice: ^device, pVolume: ^f32) -> result ---
	/*
	Sets the master volume for the device as gain in decibels.
	
	A gain of 0 is full volume, whereas a gain of < 0 will decrease the volume.
	
	
	Parameters
	----------
	pDevice (in)
	    A pointer to the device whose gain is being set.
	
	gainDB (in)
	    The new volume as gain in decibels. Must be less than or equal to 0, where 0 is full volume and anything less than 0 decreases the volume.
	
	
	Return Value
	------------
	MA_SUCCESS if the volume was set successfully.
	MA_INVALID_ARGS if pDevice is NULL.
	MA_INVALID_ARGS if the gain is > 0.
	
	
	Thread Safety
	-------------
	Safe. This just sets a local member of the device object.
	
	
	Callback Safety
	---------------
	Safe. If you set the volume in the data callback, that data written to the output buffer will have the new volume applied.
	
	
	Remarks
	-------
	This applies the gain across all channels.
	
	This does not change the operating system's volume. It only affects the volume for the given `ma_device` object's audio stream.
	
	
	See Also
	--------
	ma_device_get_master_volume_gain_db()
	ma_device_set_master_volume()
	ma_device_get_master_volume()
	*/
	device_set_master_volume_db :: proc(pDevice: ^device, gainDB: f32) -> result ---
	/*
	Retrieves the master gain in decibels.
	
	
	Parameters
	----------
	pDevice (in)
	    A pointer to the device whose gain is being retrieved.
	
	pGainDB (in)
	    A pointer to the variable that will receive the gain in decibels. The returned value will be <= 0.
	
	
	Return Value
	------------
	MA_SUCCESS if successful.
	MA_INVALID_ARGS if pDevice is NULL.
	MA_INVALID_ARGS if pGainDB is NULL.
	
	
	Thread Safety
	-------------
	Safe. This just a simple member retrieval.
	
	
	Callback Safety
	---------------
	Safe.
	
	
	Remarks
	-------
	If an error occurs, `*pGainDB` will be set to 0.
	
	
	See Also
	--------
	ma_device_set_master_volume_db()
	ma_device_set_master_volume()
	ma_device_get_master_volume()
	*/
	device_get_master_volume_db :: proc(pDevice: ^device, pGainDB: ^f32) -> result ---
	/*
	Called from the data callback of asynchronous backends to allow miniaudio to process the data and fire the miniaudio data callback.
	
	
	Parameters
	----------
	pDevice (in)
	    A pointer to device whose processing the data callback.
	
	pOutput (out)
	    A pointer to the buffer that will receive the output PCM frame data. On a playback device this must not be NULL. On a duplex device
	    this can be NULL, in which case pInput must not be NULL.
	
	pInput (in)
	    A pointer to the buffer containing input PCM frame data. On a capture device this must not be NULL. On a duplex device this can be
	    NULL, in which case `pOutput` must not be NULL.
	
	frameCount (in)
	    The number of frames being processed.
	
	
	Return Value
	------------
	MA_SUCCESS if successful; any other result code otherwise.
	
	
	Thread Safety
	-------------
	This function should only ever be called from the internal data callback of the backend. It is safe to call this simultaneously between a
	playback and capture device in duplex setups.
	
	
	Callback Safety
	---------------
	Do not call this from the miniaudio data callback. It should only ever be called from the internal data callback of the backend.
	
	
	Remarks
	-------
	If both `pOutput` and `pInput` are NULL, and error will be returned. In duplex scenarios, both `pOutput` and `pInput` can be non-NULL, in
	which case `pInput` will be processed first, followed by `pOutput`.
	
	If you are implementing a custom backend, and that backend uses a callback for data delivery, you'll need to call this from inside that
	callback.
	*/
	device_handle_backend_data_callback :: proc(pDevice: ^device, pOutput: rawptr, pInput: rawptr, frameCount: uint32) -> result ---
	/*
	Calculates an appropriate buffer size from a descriptor, native sample rate and performance profile.
	
	This function is used by backends for helping determine an appropriately sized buffer to use with
	the device depending on the values of `periodSizeInFrames` and `periodSizeInMilliseconds` in the
	`pDescriptor` object. Since buffer size calculations based on time depends on the sample rate, a
	best guess at the device's native sample rate is also required which is where `nativeSampleRate`
	comes in. In addition, the performance profile is also needed for cases where both the period size
	in frames and milliseconds are both zero.
	
	
	Parameters
	----------
	pDescriptor (in)
	    A pointer to device descriptor whose `periodSizeInFrames` and `periodSizeInMilliseconds` members
	    will be used for the calculation of the buffer size.
	
	nativeSampleRate (in)
	    The device's native sample rate. This is only ever used when the `periodSizeInFrames` member of
	    `pDescriptor` is zero. In this case, `periodSizeInMilliseconds` will be used instead, in which
	    case a sample rate is required to convert to a size in frames.
	
	performanceProfile (in)
	    When both the `periodSizeInFrames` and `periodSizeInMilliseconds` members of `pDescriptor` are
	    zero, miniaudio will fall back to a buffer size based on the performance profile. The profile
	    to use for this calculation is determine by this parameter.
	
	
	Return Value
	------------
	The calculated buffer size in frames.
	
	
	Thread Safety
	-------------
	This is safe so long as nothing modifies `pDescriptor` at the same time. However, this function
	should only ever be called from within the backend's device initialization routine and therefore
	shouldn't have any multithreading concerns.
	
	
	Callback Safety
	---------------
	This is safe to call within the data callback, but there is no reason to ever do this.
	
	
	Remarks
	-------
	If `nativeSampleRate` is zero, this function will fall back to `pDescriptor->sampleRate`. If that
	is also zero, `MA_DEFAULT_SAMPLE_RATE` will be used instead.
	*/
	calculate_buffer_size_in_frames_from_descriptor :: proc(pDescriptor: ^device_descriptor, nativeSampleRate: uint32, performanceProfile: performance_profile) -> uint32 ---
	/*
	Retrieves a friendly name for a backend.
	*/
	get_backend_name :: proc(backend: backend) -> cstring ---
	/*
	Retrieves the backend enum from the given name.
	*/
	get_backend_from_name :: proc(pBackendName: cstring, pBackend: ^backend) -> result ---
	/*
	Determines whether or not the given backend is available by the compilation environment.
	*/
	is_backend_enabled :: proc(backend: backend) -> bool32 ---
	/*
	Retrieves compile-time enabled backends.
	
	
	Parameters
	----------
	pBackends (out, optional)
	    A pointer to the buffer that will receive the enabled backends. Set to NULL to retrieve the backend count. Setting
	    the capacity of the buffer to `MA_BACKEND_COUNT` will guarantee it's large enough for all backends.
	
	backendCap (in)
	    The capacity of the `pBackends` buffer.
	
	pBackendCount (out)
	    A pointer to the variable that will receive the enabled backend count.
	
	
	Return Value
	------------
	MA_SUCCESS if successful.
	MA_INVALID_ARGS if `pBackendCount` is NULL.
	MA_NO_SPACE if the capacity of `pBackends` is not large enough.
	
	If `MA_NO_SPACE` is returned, the `pBackends` buffer will be filled with `*pBackendCount` values.
	
	
	Thread Safety
	-------------
	Safe.
	
	
	Callback Safety
	---------------
	Safe.
	
	
	Remarks
	-------
	If you want to retrieve the number of backends so you can determine the capacity of `pBackends` buffer, you can call
	this function with `pBackends` set to NULL.
	
	This will also enumerate the null backend. If you don't want to include this you need to check for `ma_backend_null`
	when you enumerate over the returned backends and handle it appropriately. Alternatively, you can disable it at
	compile time with `MA_NO_NULL`.
	
	The returned backends are determined based on compile time settings, not the platform it's currently running on. For
	example, PulseAudio will be returned if it was enabled at compile time, even when the user doesn't actually have
	PulseAudio installed.
	
	
	Example 1
	---------
	The example below retrieves the enabled backend count using a fixed sized buffer allocated on the stack. The buffer is
	given a capacity of `MA_BACKEND_COUNT` which will guarantee it'll be large enough to store all available backends.
	Since `MA_BACKEND_COUNT` is always a relatively small value, this should be suitable for most scenarios.
	
	```
	ma_backend enabledBackends[MA_BACKEND_COUNT];
	size_t enabledBackendCount;
	
	result = ma_get_enabled_backends(enabledBackends, MA_BACKEND_COUNT, &enabledBackendCount);
	if (result != MA_SUCCESS) {
	    // Failed to retrieve enabled backends. Should never happen in this example since all inputs are valid.
	}
	```
	
	
	See Also
	--------
	ma_is_backend_enabled()
	*/
	get_enabled_backends :: proc(pBackends: ^backend, backendCap: uint, pBackendCount: ^uint) -> result ---
	/*
	Determines whether or not loopback mode is support by a backend.
	*/
	is_loopback_supported :: proc(backend: backend) -> bool32 ---
	/*
	Calculates a buffer size in milliseconds (rounded up) from the specified number of frames and sample rate.
	*/
	calculate_buffer_size_in_milliseconds_from_frames :: proc(bufferSizeInFrames: uint32, sampleRate: uint32) -> uint32 ---
	/*
	Calculates a buffer size in frames from the specified number of milliseconds and sample rate.
	*/
	calculate_buffer_size_in_frames_from_milliseconds :: proc(bufferSizeInMilliseconds: uint32, sampleRate: uint32) -> uint32 ---
	/*
	Copies PCM frames from one buffer to another.
	*/
	copy_pcm_frames :: proc(dst: rawptr, src: rawptr, frameCount: uint64, format: format, channels: uint32) ---
	/*
	Copies silent frames into the given buffer.
	
	Remarks
	-------
	For all formats except `ma_format_u8`, the output buffer will be filled with 0. For `ma_format_u8` it will be filled with 128. The reason for this is that it
	makes more sense for the purpose of mixing to initialize it to the center point.
	*/
	silence_pcm_frames :: proc(p: rawptr, frameCount: uint64, format: format, channels: uint32) ---
	/*
	Offsets a pointer by the specified number of PCM frames.
	*/
	offset_pcm_frames_ptr :: proc(p: rawptr, offsetInFrames: uint64, format: format, channels: uint32) -> rawptr ---
	offset_pcm_frames_const_ptr :: proc(p: rawptr, offsetInFrames: uint64, format: format, channels: uint32) -> rawptr ---
	/*
	Clips samples.
	*/
	clip_samples_u8 :: proc(pDst: ^uint8, pSrc: ^int16, count: uint64) ---
	clip_samples_s16 :: proc(pDst: ^int16, pSrc: ^int32, count: uint64) ---
	clip_samples_s24 :: proc(pDst: ^uint8, pSrc: ^int64, count: uint64) ---
	clip_samples_s32 :: proc(pDst: ^int32, pSrc: ^int64, count: uint64) ---
	clip_samples_f32 :: proc(pDst: ^f32, pSrc: ^f32, count: uint64) ---
	clip_pcm_frames :: proc(pDst: rawptr, pSrc: rawptr, frameCount: uint64, format: format, channels: uint32) ---
	/*
	Helper for applying a volume factor to samples.
	
	Note that the source and destination buffers can be the same, in which case it'll perform the operation in-place.
	*/
	copy_and_apply_volume_factor_u8 :: proc(pSamplesOut: ^uint8, pSamplesIn: ^uint8, sampleCount: uint64, factor: f32) ---
	copy_and_apply_volume_factor_s16 :: proc(pSamplesOut: ^int16, pSamplesIn: ^int16, sampleCount: uint64, factor: f32) ---
	copy_and_apply_volume_factor_s24 :: proc(pSamplesOut: rawptr, pSamplesIn: rawptr, sampleCount: uint64, factor: f32) ---
	copy_and_apply_volume_factor_s32 :: proc(pSamplesOut: ^int32, pSamplesIn: ^int32, sampleCount: uint64, factor: f32) ---
	copy_and_apply_volume_factor_f32 :: proc(pSamplesOut: ^f32, pSamplesIn: ^f32, sampleCount: uint64, factor: f32) ---
	apply_volume_factor_u8 :: proc(pSamples: ^uint8, sampleCount: uint64, factor: f32) ---
	apply_volume_factor_s16 :: proc(pSamples: ^int16, sampleCount: uint64, factor: f32) ---
	apply_volume_factor_s24 :: proc(pSamples: rawptr, sampleCount: uint64, factor: f32) ---
	apply_volume_factor_s32 :: proc(pSamples: ^int32, sampleCount: uint64, factor: f32) ---
	apply_volume_factor_f32 :: proc(pSamples: ^f32, sampleCount: uint64, factor: f32) ---
	copy_and_apply_volume_factor_pcm_frames_u8 :: proc(pFramesOut: ^uint8, pFramesIn: ^uint8, frameCount: uint64, channels: uint32, factor: f32) ---
	copy_and_apply_volume_factor_pcm_frames_s16 :: proc(pFramesOut: ^int16, pFramesIn: ^int16, frameCount: uint64, channels: uint32, factor: f32) ---
	copy_and_apply_volume_factor_pcm_frames_s24 :: proc(pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64, channels: uint32, factor: f32) ---
	copy_and_apply_volume_factor_pcm_frames_s32 :: proc(pFramesOut: ^int32, pFramesIn: ^int32, frameCount: uint64, channels: uint32, factor: f32) ---
	copy_and_apply_volume_factor_pcm_frames_f32 :: proc(pFramesOut: ^f32, pFramesIn: ^f32, frameCount: uint64, channels: uint32, factor: f32) ---
	copy_and_apply_volume_factor_pcm_frames :: proc(pFramesOut: rawptr, pFramesIn: rawptr, frameCount: uint64, format: format, channels: uint32, factor: f32) ---
	apply_volume_factor_pcm_frames_u8 :: proc(pFrames: ^uint8, frameCount: uint64, channels: uint32, factor: f32) ---
	apply_volume_factor_pcm_frames_s16 :: proc(pFrames: ^int16, frameCount: uint64, channels: uint32, factor: f32) ---
	apply_volume_factor_pcm_frames_s24 :: proc(pFrames: rawptr, frameCount: uint64, channels: uint32, factor: f32) ---
	apply_volume_factor_pcm_frames_s32 :: proc(pFrames: ^int32, frameCount: uint64, channels: uint32, factor: f32) ---
	apply_volume_factor_pcm_frames_f32 :: proc(pFrames: ^f32, frameCount: uint64, channels: uint32, factor: f32) ---
	apply_volume_factor_pcm_frames :: proc(pFrames: rawptr, frameCount: uint64, format: format, channels: uint32, factor: f32) ---
	copy_and_apply_volume_factor_per_channel_f32 :: proc(pFramesOut: ^f32, pFramesIn: ^f32, frameCount: uint64, channels: uint32, pChannelGains: ^f32) ---
	copy_and_apply_volume_and_clip_samples_u8 :: proc(pDst: ^uint8, pSrc: ^int16, count: uint64, volume: f32) ---
	copy_and_apply_volume_and_clip_samples_s16 :: proc(pDst: ^int16, pSrc: ^int32, count: uint64, volume: f32) ---
	copy_and_apply_volume_and_clip_samples_s24 :: proc(pDst: ^uint8, pSrc: ^int64, count: uint64, volume: f32) ---
	copy_and_apply_volume_and_clip_samples_s32 :: proc(pDst: ^int32, pSrc: ^int64, count: uint64, volume: f32) ---
	copy_and_apply_volume_and_clip_samples_f32 :: proc(pDst: ^f32, pSrc: ^f32, count: uint64, volume: f32) ---
	copy_and_apply_volume_and_clip_pcm_frames :: proc(pDst: rawptr, pSrc: rawptr, frameCount: uint64, format: format, channels: uint32, volume: f32) ---
	/*
	Helper for converting a linear factor to gain in decibels.
	*/
	volume_linear_to_db :: proc(factor: f32) -> f32 ---
	/*
	Helper for converting gain in decibels to a linear factor.
	*/
	volume_db_to_linear :: proc(gain: f32) -> f32 ---
	/*
	Mixes the specified number of frames in floating point format with a volume factor.
	
	This will run on an optimized path when the volume is equal to 1.
	*/
	mix_pcm_frames_f32 :: proc(pDst: ^f32, pSrc: ^f32, frameCount: uint64, channels: uint32, volume: f32) -> result ---
	vfs_open :: proc(pVFS: ^ma_vfs, pFilePath: cstring, openMode: uint32, pFile: ^vfs_file) -> result ---
	vfs_open_w :: proc(pVFS: ^ma_vfs, pFilePath: ^i32, openMode: uint32, pFile: ^vfs_file) -> result ---
	vfs_close :: proc(pVFS: ^ma_vfs, file: vfs_file) -> result ---
	vfs_read :: proc(pVFS: ^ma_vfs, file: vfs_file, pDst: rawptr, sizeInBytes: uint, pBytesRead: ^uint) -> result ---
	vfs_write :: proc(pVFS: ^ma_vfs, file: vfs_file, pSrc: rawptr, sizeInBytes: uint, pBytesWritten: ^uint) -> result ---
	vfs_seek :: proc(pVFS: ^ma_vfs, file: vfs_file, offset: int64, origin: seek_origin) -> result ---
	vfs_tell :: proc(pVFS: ^ma_vfs, file: vfs_file, pCursor: ^int64) -> result ---
	vfs_info :: proc(pVFS: ^ma_vfs, file: vfs_file, pInfo: ^file_info) -> result ---
	vfs_open_and_read_file :: proc(pVFS: ^ma_vfs, pFilePath: cstring, ppData: ^rawptr, pSize: ^uint, pAllocationCallbacks: ^allocation_callbacks) -> result ---
	default_vfs_init :: proc(pVFS: ^default_vfs, pAllocationCallbacks: ^allocation_callbacks) -> result ---
	decoding_backend_config_init :: proc(preferredFormat: format, seekPointCount: uint32) -> decoding_backend_config ---
	decoder_config_init :: proc(outputFormat: format, outputChannels: uint32, outputSampleRate: uint32) -> decoder_config ---
	decoder_config_init_default :: proc() -> decoder_config ---
	decoder_init :: proc(onRead: decoder_read_proc, onSeek: decoder_seek_proc, pUserData: rawptr, pConfig: ^decoder_config, pDecoder: ^decoder) -> result ---
	decoder_init_memory :: proc(pData: rawptr, dataSize: uint, pConfig: ^decoder_config, pDecoder: ^decoder) -> result ---
	decoder_init_vfs :: proc(pVFS: ^ma_vfs, pFilePath: cstring, pConfig: ^decoder_config, pDecoder: ^decoder) -> result ---
	decoder_init_vfs_w :: proc(pVFS: ^ma_vfs, pFilePath: ^i32, pConfig: ^decoder_config, pDecoder: ^decoder) -> result ---
	decoder_init_file :: proc(pFilePath: cstring, pConfig: ^decoder_config, pDecoder: ^decoder) -> result ---
	decoder_init_file_w :: proc(pFilePath: ^i32, pConfig: ^decoder_config, pDecoder: ^decoder) -> result ---
	/*
	Uninitializes a decoder.
	*/
	decoder_uninit :: proc(pDecoder: ^decoder) -> result ---
	/*
	Reads PCM frames from the given decoder.
	
	This is not thread safe without your own synchronization.
	*/
	decoder_read_pcm_frames :: proc(pDecoder: ^decoder, pFramesOut: rawptr, frameCount: uint64, pFramesRead: ^uint64) -> result ---
	/*
	Seeks to a PCM frame based on its absolute index.
	
	This is not thread safe without your own synchronization.
	*/
	decoder_seek_to_pcm_frame :: proc(pDecoder: ^decoder, frameIndex: uint64) -> result ---
	/*
	Retrieves the decoder's output data format.
	*/
	decoder_get_data_format :: proc(pDecoder: ^decoder, pFormat: ^format, pChannels: ^uint32, pSampleRate: ^uint32, pChannelMap: ^channel, channelMapCap: uint) -> result ---
	/*
	Retrieves the current position of the read cursor in PCM frames.
	*/
	decoder_get_cursor_in_pcm_frames :: proc(pDecoder: ^decoder, pCursor: ^uint64) -> result ---
	/*
	Retrieves the length of the decoder in PCM frames.
	
	Do not call this on streams of an undefined length, such as internet radio.
	
	If the length is unknown or an error occurs, 0 will be returned.
	
	This will always return 0 for Vorbis decoders. This is due to a limitation with stb_vorbis in push mode which is what miniaudio
	uses internally.
	
	For MP3's, this will decode the entire file. Do not call this in time critical scenarios.
	
	This function is not thread safe without your own synchronization.
	*/
	decoder_get_length_in_pcm_frames :: proc(pDecoder: ^decoder, pLength: ^uint64) -> result ---
	/*
	Retrieves the number of frames that can be read before reaching the end.
	
	This calls `ma_decoder_get_length_in_pcm_frames()` so you need to be aware of the rules for that function, in
	particular ensuring you do not call it on streams of an undefined length, such as internet radio.
	
	If the total length of the decoder cannot be retrieved, such as with Vorbis decoders, `MA_NOT_IMPLEMENTED` will be
	returned.
	*/
	decoder_get_available_frames :: proc(pDecoder: ^decoder, pAvailableFrames: ^uint64) -> result ---
	/*
	Helper for opening and decoding a file into a heap allocated block of memory. Free the returned pointer with ma_free(). On input,
	pConfig should be set to what you want. On output it will be set to what you got.
	*/
	decode_from_vfs :: proc(pVFS: ^ma_vfs, pFilePath: cstring, pConfig: ^decoder_config, pFrameCountOut: ^uint64, ppPCMFramesOut: ^rawptr) -> result ---
	decode_file :: proc(pFilePath: cstring, pConfig: ^decoder_config, pFrameCountOut: ^uint64, ppPCMFramesOut: ^rawptr) -> result ---
	decode_memory :: proc(pData: rawptr, dataSize: uint, pConfig: ^decoder_config, pFrameCountOut: ^uint64, ppPCMFramesOut: ^rawptr) -> result ---
	encoder_config_init :: proc(encodingFormat: encoding_format, format: format, channels: uint32, sampleRate: uint32) -> encoder_config ---
	encoder_init :: proc(onWrite: encoder_write_proc, onSeek: encoder_seek_proc, pUserData: rawptr, pConfig: ^encoder_config, pEncoder: ^encoder) -> result ---
	encoder_init_vfs :: proc(pVFS: ^ma_vfs, pFilePath: cstring, pConfig: ^encoder_config, pEncoder: ^encoder) -> result ---
	encoder_init_vfs_w :: proc(pVFS: ^ma_vfs, pFilePath: ^i32, pConfig: ^encoder_config, pEncoder: ^encoder) -> result ---
	encoder_init_file :: proc(pFilePath: cstring, pConfig: ^encoder_config, pEncoder: ^encoder) -> result ---
	encoder_init_file_w :: proc(pFilePath: ^i32, pConfig: ^encoder_config, pEncoder: ^encoder) -> result ---
	encoder_uninit :: proc(pEncoder: ^encoder) ---
	encoder_write_pcm_frames :: proc(pEncoder: ^encoder, pFramesIn: rawptr, frameCount: uint64, pFramesWritten: ^uint64) -> result ---
	waveform_config_init :: proc(format: format, channels: uint32, sampleRate: uint32, type: waveform_type, amplitude: f64, frequency: f64) -> waveform_config ---
	waveform_init :: proc(pConfig: ^waveform_config, pWaveform: ^waveform) -> result ---
	waveform_uninit :: proc(pWaveform: ^waveform) ---
	waveform_read_pcm_frames :: proc(pWaveform: ^waveform, pFramesOut: rawptr, frameCount: uint64, pFramesRead: ^uint64) -> result ---
	waveform_seek_to_pcm_frame :: proc(pWaveform: ^waveform, frameIndex: uint64) -> result ---
	waveform_set_amplitude :: proc(pWaveform: ^waveform, amplitude: f64) -> result ---
	waveform_set_frequency :: proc(pWaveform: ^waveform, frequency: f64) -> result ---
	waveform_set_type :: proc(pWaveform: ^waveform, type: waveform_type) -> result ---
	waveform_set_sample_rate :: proc(pWaveform: ^waveform, sampleRate: uint32) -> result ---
	pulsewave_config_init :: proc(format: format, channels: uint32, sampleRate: uint32, dutyCycle: f64, amplitude: f64, frequency: f64) -> pulsewave_config ---
	pulsewave_init :: proc(pConfig: ^pulsewave_config, pWaveform: ^pulsewave) -> result ---
	pulsewave_uninit :: proc(pWaveform: ^pulsewave) ---
	pulsewave_read_pcm_frames :: proc(pWaveform: ^pulsewave, pFramesOut: rawptr, frameCount: uint64, pFramesRead: ^uint64) -> result ---
	pulsewave_seek_to_pcm_frame :: proc(pWaveform: ^pulsewave, frameIndex: uint64) -> result ---
	pulsewave_set_amplitude :: proc(pWaveform: ^pulsewave, amplitude: f64) -> result ---
	pulsewave_set_frequency :: proc(pWaveform: ^pulsewave, frequency: f64) -> result ---
	pulsewave_set_sample_rate :: proc(pWaveform: ^pulsewave, sampleRate: uint32) -> result ---
	pulsewave_set_duty_cycle :: proc(pWaveform: ^pulsewave, dutyCycle: f64) -> result ---
	noise_config_init :: proc(format: format, channels: uint32, type: noise_type, seed: int32, amplitude: f64) -> noise_config ---
	noise_get_heap_size :: proc(pConfig: ^noise_config, pHeapSizeInBytes: ^uint) -> result ---
	noise_init_preallocated :: proc(pConfig: ^noise_config, pHeap: rawptr, pNoise: ^noise) -> result ---
	noise_init :: proc(pConfig: ^noise_config, pAllocationCallbacks: ^allocation_callbacks, pNoise: ^noise) -> result ---
	noise_uninit :: proc(pNoise: ^noise, pAllocationCallbacks: ^allocation_callbacks) ---
	noise_read_pcm_frames :: proc(pNoise: ^noise, pFramesOut: rawptr, frameCount: uint64, pFramesRead: ^uint64) -> result ---
	noise_set_amplitude :: proc(pNoise: ^noise, amplitude: f64) -> result ---
	noise_set_seed :: proc(pNoise: ^noise, seed: int32) -> result ---
	noise_set_type :: proc(pNoise: ^noise, type: noise_type) -> result ---
	resource_manager_pipeline_notifications_init :: proc() -> resource_manager_pipeline_notifications ---
	resource_manager_data_source_config_init :: proc() -> resource_manager_data_source_config ---
	resource_manager_config_init :: proc() -> resource_manager_config ---
	/* Init. */
	resource_manager_init :: proc(pConfig: ^resource_manager_config, pResourceManager: ^resource_manager) -> result ---
	resource_manager_uninit :: proc(pResourceManager: ^resource_manager) ---
	resource_manager_get_log :: proc(pResourceManager: ^resource_manager) -> ^log ---
	/* Registration. */
	resource_manager_register_file :: proc(pResourceManager: ^resource_manager, pFilePath: cstring, flags: uint32) -> result ---
	resource_manager_register_file_w :: proc(pResourceManager: ^resource_manager, pFilePath: ^i32, flags: uint32) -> result ---
	resource_manager_register_decoded_data :: proc(pResourceManager: ^resource_manager, pName: cstring, pData: rawptr, frameCount: uint64, format: format, channels: uint32, sampleRate: uint32) -> result ---
	resource_manager_register_decoded_data_w :: proc(pResourceManager: ^resource_manager, pName: ^i32, pData: rawptr, frameCount: uint64, format: format, channels: uint32, sampleRate: uint32) -> result ---
	resource_manager_register_encoded_data :: proc(pResourceManager: ^resource_manager, pName: cstring, pData: rawptr, sizeInBytes: uint) -> result ---
	resource_manager_register_encoded_data_w :: proc(pResourceManager: ^resource_manager, pName: ^i32, pData: rawptr, sizeInBytes: uint) -> result ---
	resource_manager_unregister_file :: proc(pResourceManager: ^resource_manager, pFilePath: cstring) -> result ---
	resource_manager_unregister_file_w :: proc(pResourceManager: ^resource_manager, pFilePath: ^i32) -> result ---
	resource_manager_unregister_data :: proc(pResourceManager: ^resource_manager, pName: cstring) -> result ---
	resource_manager_unregister_data_w :: proc(pResourceManager: ^resource_manager, pName: ^i32) -> result ---
	/* Data Buffers. */
	resource_manager_data_buffer_init_ex :: proc(pResourceManager: ^resource_manager, pConfig: ^resource_manager_data_source_config, pDataBuffer: ^resource_manager_data_buffer) -> result ---
	resource_manager_data_buffer_init :: proc(pResourceManager: ^resource_manager, pFilePath: cstring, flags: uint32, pNotifications: ^resource_manager_pipeline_notifications, pDataBuffer: ^resource_manager_data_buffer) -> result ---
	resource_manager_data_buffer_init_w :: proc(pResourceManager: ^resource_manager, pFilePath: ^i32, flags: uint32, pNotifications: ^resource_manager_pipeline_notifications, pDataBuffer: ^resource_manager_data_buffer) -> result ---
	resource_manager_data_buffer_init_copy :: proc(pResourceManager: ^resource_manager, pExistingDataBuffer: ^resource_manager_data_buffer, pDataBuffer: ^resource_manager_data_buffer) -> result ---
	resource_manager_data_buffer_uninit :: proc(pDataBuffer: ^resource_manager_data_buffer) -> result ---
	resource_manager_data_buffer_read_pcm_frames :: proc(pDataBuffer: ^resource_manager_data_buffer, pFramesOut: rawptr, frameCount: uint64, pFramesRead: ^uint64) -> result ---
	resource_manager_data_buffer_seek_to_pcm_frame :: proc(pDataBuffer: ^resource_manager_data_buffer, frameIndex: uint64) -> result ---
	resource_manager_data_buffer_get_data_format :: proc(pDataBuffer: ^resource_manager_data_buffer, pFormat: ^format, pChannels: ^uint32, pSampleRate: ^uint32, pChannelMap: ^channel, channelMapCap: uint) -> result ---
	resource_manager_data_buffer_get_cursor_in_pcm_frames :: proc(pDataBuffer: ^resource_manager_data_buffer, pCursor: ^uint64) -> result ---
	resource_manager_data_buffer_get_length_in_pcm_frames :: proc(pDataBuffer: ^resource_manager_data_buffer, pLength: ^uint64) -> result ---
	resource_manager_data_buffer_result :: proc(pDataBuffer: ^resource_manager_data_buffer) -> result ---
	resource_manager_data_buffer_set_looping :: proc(pDataBuffer: ^resource_manager_data_buffer, isLooping: bool32) -> result ---
	resource_manager_data_buffer_is_looping :: proc(pDataBuffer: ^resource_manager_data_buffer) -> bool32 ---
	resource_manager_data_buffer_get_available_frames :: proc(pDataBuffer: ^resource_manager_data_buffer, pAvailableFrames: ^uint64) -> result ---
	/* Data Streams. */
	resource_manager_data_stream_init_ex :: proc(pResourceManager: ^resource_manager, pConfig: ^resource_manager_data_source_config, pDataStream: ^resource_manager_data_stream) -> result ---
	resource_manager_data_stream_init :: proc(pResourceManager: ^resource_manager, pFilePath: cstring, flags: uint32, pNotifications: ^resource_manager_pipeline_notifications, pDataStream: ^resource_manager_data_stream) -> result ---
	resource_manager_data_stream_init_w :: proc(pResourceManager: ^resource_manager, pFilePath: ^i32, flags: uint32, pNotifications: ^resource_manager_pipeline_notifications, pDataStream: ^resource_manager_data_stream) -> result ---
	resource_manager_data_stream_uninit :: proc(pDataStream: ^resource_manager_data_stream) -> result ---
	resource_manager_data_stream_read_pcm_frames :: proc(pDataStream: ^resource_manager_data_stream, pFramesOut: rawptr, frameCount: uint64, pFramesRead: ^uint64) -> result ---
	resource_manager_data_stream_seek_to_pcm_frame :: proc(pDataStream: ^resource_manager_data_stream, frameIndex: uint64) -> result ---
	resource_manager_data_stream_get_data_format :: proc(pDataStream: ^resource_manager_data_stream, pFormat: ^format, pChannels: ^uint32, pSampleRate: ^uint32, pChannelMap: ^channel, channelMapCap: uint) -> result ---
	resource_manager_data_stream_get_cursor_in_pcm_frames :: proc(pDataStream: ^resource_manager_data_stream, pCursor: ^uint64) -> result ---
	resource_manager_data_stream_get_length_in_pcm_frames :: proc(pDataStream: ^resource_manager_data_stream, pLength: ^uint64) -> result ---
	resource_manager_data_stream_result :: proc(pDataStream: ^resource_manager_data_stream) -> result ---
	resource_manager_data_stream_set_looping :: proc(pDataStream: ^resource_manager_data_stream, isLooping: bool32) -> result ---
	resource_manager_data_stream_is_looping :: proc(pDataStream: ^resource_manager_data_stream) -> bool32 ---
	resource_manager_data_stream_get_available_frames :: proc(pDataStream: ^resource_manager_data_stream, pAvailableFrames: ^uint64) -> result ---
	/* Data Sources. */
	resource_manager_data_source_init_ex :: proc(pResourceManager: ^resource_manager, pConfig: ^resource_manager_data_source_config, pDataSource: ^resource_manager_data_source) -> result ---
	resource_manager_data_source_init :: proc(pResourceManager: ^resource_manager, pName: cstring, flags: uint32, pNotifications: ^resource_manager_pipeline_notifications, pDataSource: ^resource_manager_data_source) -> result ---
	resource_manager_data_source_init_w :: proc(pResourceManager: ^resource_manager, pName: ^i32, flags: uint32, pNotifications: ^resource_manager_pipeline_notifications, pDataSource: ^resource_manager_data_source) -> result ---
	resource_manager_data_source_init_copy :: proc(pResourceManager: ^resource_manager, pExistingDataSource: ^resource_manager_data_source, pDataSource: ^resource_manager_data_source) -> result ---
	resource_manager_data_source_uninit :: proc(pDataSource: ^resource_manager_data_source) -> result ---
	resource_manager_data_source_read_pcm_frames :: proc(pDataSource: ^resource_manager_data_source, pFramesOut: rawptr, frameCount: uint64, pFramesRead: ^uint64) -> result ---
	resource_manager_data_source_seek_to_pcm_frame :: proc(pDataSource: ^resource_manager_data_source, frameIndex: uint64) -> result ---
	resource_manager_data_source_get_data_format :: proc(pDataSource: ^resource_manager_data_source, pFormat: ^format, pChannels: ^uint32, pSampleRate: ^uint32, pChannelMap: ^channel, channelMapCap: uint) -> result ---
	resource_manager_data_source_get_cursor_in_pcm_frames :: proc(pDataSource: ^resource_manager_data_source, pCursor: ^uint64) -> result ---
	resource_manager_data_source_get_length_in_pcm_frames :: proc(pDataSource: ^resource_manager_data_source, pLength: ^uint64) -> result ---
	resource_manager_data_source_result :: proc(pDataSource: ^resource_manager_data_source) -> result ---
	resource_manager_data_source_set_looping :: proc(pDataSource: ^resource_manager_data_source, isLooping: bool32) -> result ---
	resource_manager_data_source_is_looping :: proc(pDataSource: ^resource_manager_data_source) -> bool32 ---
	resource_manager_data_source_get_available_frames :: proc(pDataSource: ^resource_manager_data_source, pAvailableFrames: ^uint64) -> result ---
	/* Job management. */
	resource_manager_post_job :: proc(pResourceManager: ^resource_manager, pJob: ^job) -> result ---
	resource_manager_post_job_quit :: proc(pResourceManager: ^resource_manager) -> result ---
	resource_manager_next_job :: proc(pResourceManager: ^resource_manager, pJob: ^job) -> result ---
	resource_manager_process_job :: proc(pResourceManager: ^resource_manager, pJob: ^job) -> result ---
	resource_manager_process_next_job :: proc(pResourceManager: ^resource_manager) -> result ---
	node_config_init :: proc() -> node_config ---
	node_get_heap_size :: proc(pNodeGraph: ^node_graph, pConfig: ^node_config, pHeapSizeInBytes: ^uint) -> result ---
	node_init_preallocated :: proc(pNodeGraph: ^node_graph, pConfig: ^node_config, pHeap: rawptr, pNode: ^ma_node) -> result ---
	node_init :: proc(pNodeGraph: ^node_graph, pConfig: ^node_config, pAllocationCallbacks: ^allocation_callbacks, pNode: ^ma_node) -> result ---
	node_uninit :: proc(pNode: ^ma_node, pAllocationCallbacks: ^allocation_callbacks) ---
	node_get_node_graph :: proc(pNode: ^ma_node) -> ^node_graph ---
	node_get_input_bus_count :: proc(pNode: ^ma_node) -> uint32 ---
	node_get_output_bus_count :: proc(pNode: ^ma_node) -> uint32 ---
	node_get_input_channels :: proc(pNode: ^ma_node, inputBusIndex: uint32) -> uint32 ---
	node_get_output_channels :: proc(pNode: ^ma_node, outputBusIndex: uint32) -> uint32 ---
	node_attach_output_bus :: proc(pNode: ^ma_node, outputBusIndex: uint32, pOtherNode: ^ma_node, otherNodeInputBusIndex: uint32) -> result ---
	node_detach_output_bus :: proc(pNode: ^ma_node, outputBusIndex: uint32) -> result ---
	node_detach_all_output_buses :: proc(pNode: ^ma_node) -> result ---
	node_set_output_bus_volume :: proc(pNode: ^ma_node, outputBusIndex: uint32, volume: f32) -> result ---
	node_get_output_bus_volume :: proc(pNode: ^ma_node, outputBusIndex: uint32) -> f32 ---
	node_set_state :: proc(pNode: ^ma_node, state: node_state) -> result ---
	node_get_state :: proc(pNode: ^ma_node) -> node_state ---
	node_set_state_time :: proc(pNode: ^ma_node, state: node_state, globalTime: uint64) -> result ---
	node_get_state_time :: proc(pNode: ^ma_node, state: node_state) -> uint64 ---
	node_get_state_by_time :: proc(pNode: ^ma_node, globalTime: uint64) -> node_state ---
	node_get_state_by_time_range :: proc(pNode: ^ma_node, globalTimeBeg: uint64, globalTimeEnd: uint64) -> node_state ---
	node_get_time :: proc(pNode: ^ma_node) -> uint64 ---
	node_set_time :: proc(pNode: ^ma_node, localTime: uint64) -> result ---
	node_graph_config_init :: proc(channels: uint32) -> node_graph_config ---
	node_graph_init :: proc(pConfig: ^node_graph_config, pAllocationCallbacks: ^allocation_callbacks, pNodeGraph: ^node_graph) -> result ---
	node_graph_uninit :: proc(pNodeGraph: ^node_graph, pAllocationCallbacks: ^allocation_callbacks) ---
	node_graph_get_endpoint :: proc(pNodeGraph: ^node_graph) -> ^ma_node ---
	node_graph_read_pcm_frames :: proc(pNodeGraph: ^node_graph, pFramesOut: rawptr, frameCount: uint64, pFramesRead: ^uint64) -> result ---
	node_graph_get_channels :: proc(pNodeGraph: ^node_graph) -> uint32 ---
	node_graph_get_time :: proc(pNodeGraph: ^node_graph) -> uint64 ---
	node_graph_set_time :: proc(pNodeGraph: ^node_graph, globalTime: uint64) -> result ---
	node_graph_get_processing_size_in_frames :: proc(pNodeGraph: ^node_graph) -> uint32 ---
	data_source_node_config_init :: proc(pDataSource: ^ma_data_source) -> data_source_node_config ---
	data_source_node_init :: proc(pNodeGraph: ^node_graph, pConfig: ^data_source_node_config, pAllocationCallbacks: ^allocation_callbacks, pDataSourceNode: ^data_source_node) -> result ---
	data_source_node_uninit :: proc(pDataSourceNode: ^data_source_node, pAllocationCallbacks: ^allocation_callbacks) ---
	data_source_node_set_looping :: proc(pDataSourceNode: ^data_source_node, isLooping: bool32) -> result ---
	data_source_node_is_looping :: proc(pDataSourceNode: ^data_source_node) -> bool32 ---
	splitter_node_config_init :: proc(channels: uint32) -> splitter_node_config ---
	splitter_node_init :: proc(pNodeGraph: ^node_graph, pConfig: ^splitter_node_config, pAllocationCallbacks: ^allocation_callbacks, pSplitterNode: ^splitter_node) -> result ---
	splitter_node_uninit :: proc(pSplitterNode: ^splitter_node, pAllocationCallbacks: ^allocation_callbacks) ---
	biquad_node_config_init :: proc(channels: uint32, b0: f32, b1: f32, b2: f32, a0: f32, a1: f32, a2: f32) -> biquad_node_config ---
	biquad_node_init :: proc(pNodeGraph: ^node_graph, pConfig: ^biquad_node_config, pAllocationCallbacks: ^allocation_callbacks, pNode: ^biquad_node) -> result ---
	biquad_node_reinit :: proc(pConfig: ^biquad_config, pNode: ^biquad_node) -> result ---
	biquad_node_uninit :: proc(pNode: ^biquad_node, pAllocationCallbacks: ^allocation_callbacks) ---
	lpf_node_config_init :: proc(channels: uint32, sampleRate: uint32, cutoffFrequency: f64, order: uint32) -> lpf_node_config ---
	lpf_node_init :: proc(pNodeGraph: ^node_graph, pConfig: ^lpf_node_config, pAllocationCallbacks: ^allocation_callbacks, pNode: ^lpf_node) -> result ---
	lpf_node_reinit :: proc(pConfig: ^lpf_config, pNode: ^lpf_node) -> result ---
	lpf_node_uninit :: proc(pNode: ^lpf_node, pAllocationCallbacks: ^allocation_callbacks) ---
	hpf_node_config_init :: proc(channels: uint32, sampleRate: uint32, cutoffFrequency: f64, order: uint32) -> hpf_node_config ---
	hpf_node_init :: proc(pNodeGraph: ^node_graph, pConfig: ^hpf_node_config, pAllocationCallbacks: ^allocation_callbacks, pNode: ^hpf_node) -> result ---
	hpf_node_reinit :: proc(pConfig: ^hpf_config, pNode: ^hpf_node) -> result ---
	hpf_node_uninit :: proc(pNode: ^hpf_node, pAllocationCallbacks: ^allocation_callbacks) ---
	bpf_node_config_init :: proc(channels: uint32, sampleRate: uint32, cutoffFrequency: f64, order: uint32) -> bpf_node_config ---
	bpf_node_init :: proc(pNodeGraph: ^node_graph, pConfig: ^bpf_node_config, pAllocationCallbacks: ^allocation_callbacks, pNode: ^bpf_node) -> result ---
	bpf_node_reinit :: proc(pConfig: ^bpf_config, pNode: ^bpf_node) -> result ---
	bpf_node_uninit :: proc(pNode: ^bpf_node, pAllocationCallbacks: ^allocation_callbacks) ---
	notch_node_config_init :: proc(channels: uint32, sampleRate: uint32, q: f64, frequency: f64) -> notch_node_config ---
	notch_node_init :: proc(pNodeGraph: ^node_graph, pConfig: ^notch_node_config, pAllocationCallbacks: ^allocation_callbacks, pNode: ^notch_node) -> result ---
	notch_node_reinit :: proc(pConfig: ^notch_config, pNode: ^notch_node) -> result ---
	notch_node_uninit :: proc(pNode: ^notch_node, pAllocationCallbacks: ^allocation_callbacks) ---
	peak_node_config_init :: proc(channels: uint32, sampleRate: uint32, gainDB: f64, q: f64, frequency: f64) -> peak_node_config ---
	peak_node_init :: proc(pNodeGraph: ^node_graph, pConfig: ^peak_node_config, pAllocationCallbacks: ^allocation_callbacks, pNode: ^peak_node) -> result ---
	peak_node_reinit :: proc(pConfig: ^peak_config, pNode: ^peak_node) -> result ---
	peak_node_uninit :: proc(pNode: ^peak_node, pAllocationCallbacks: ^allocation_callbacks) ---
	loshelf_node_config_init :: proc(channels: uint32, sampleRate: uint32, gainDB: f64, q: f64, frequency: f64) -> loshelf_node_config ---
	loshelf_node_init :: proc(pNodeGraph: ^node_graph, pConfig: ^loshelf_node_config, pAllocationCallbacks: ^allocation_callbacks, pNode: ^loshelf_node) -> result ---
	loshelf_node_reinit :: proc(pConfig: ^loshelf_config, pNode: ^loshelf_node) -> result ---
	loshelf_node_uninit :: proc(pNode: ^loshelf_node, pAllocationCallbacks: ^allocation_callbacks) ---
	hishelf_node_config_init :: proc(channels: uint32, sampleRate: uint32, gainDB: f64, q: f64, frequency: f64) -> hishelf_node_config ---
	hishelf_node_init :: proc(pNodeGraph: ^node_graph, pConfig: ^hishelf_node_config, pAllocationCallbacks: ^allocation_callbacks, pNode: ^hishelf_node) -> result ---
	hishelf_node_reinit :: proc(pConfig: ^hishelf_config, pNode: ^hishelf_node) -> result ---
	hishelf_node_uninit :: proc(pNode: ^hishelf_node, pAllocationCallbacks: ^allocation_callbacks) ---
	delay_node_config_init :: proc(channels: uint32, sampleRate: uint32, delayInFrames: uint32, decay: f32) -> delay_node_config ---
	delay_node_init :: proc(pNodeGraph: ^node_graph, pConfig: ^delay_node_config, pAllocationCallbacks: ^allocation_callbacks, pDelayNode: ^delay_node) -> result ---
	delay_node_uninit :: proc(pDelayNode: ^delay_node, pAllocationCallbacks: ^allocation_callbacks) ---
	delay_node_set_wet :: proc(pDelayNode: ^delay_node, value: f32) ---
	delay_node_get_wet :: proc(pDelayNode: ^delay_node) -> f32 ---
	delay_node_set_dry :: proc(pDelayNode: ^delay_node, value: f32) ---
	delay_node_get_dry :: proc(pDelayNode: ^delay_node) -> f32 ---
	delay_node_set_decay :: proc(pDelayNode: ^delay_node, value: f32) ---
	delay_node_get_decay :: proc(pDelayNode: ^delay_node) -> f32 ---
	engine_node_config_init :: proc(pEngine: ^engine, type: engine_node_type, flags: uint32) -> engine_node_config ---
	engine_node_get_heap_size :: proc(pConfig: ^engine_node_config, pHeapSizeInBytes: ^uint) -> result ---
	engine_node_init_preallocated :: proc(pConfig: ^engine_node_config, pHeap: rawptr, pEngineNode: ^engine_node) -> result ---
	engine_node_init :: proc(pConfig: ^engine_node_config, pAllocationCallbacks: ^allocation_callbacks, pEngineNode: ^engine_node) -> result ---
	engine_node_uninit :: proc(pEngineNode: ^engine_node, pAllocationCallbacks: ^allocation_callbacks) ---
	sound_config_init :: proc() -> sound_config ---
	sound_config_init_2 :: proc(pEngine: ^engine) -> sound_config ---
	sound_group_config_init :: proc() -> sound_group_config ---
	sound_group_config_init_2 :: proc(pEngine: ^engine) -> sound_group_config ---
	engine_config_init :: proc() -> engine_config ---
	engine_init :: proc(pConfig: ^engine_config, pEngine: ^engine) -> result ---
	engine_uninit :: proc(pEngine: ^engine) ---
	engine_read_pcm_frames :: proc(pEngine: ^engine, pFramesOut: rawptr, frameCount: uint64, pFramesRead: ^uint64) -> result ---
	engine_get_node_graph :: proc(pEngine: ^engine) -> ^node_graph ---
	engine_get_resource_manager :: proc(pEngine: ^engine) -> ^resource_manager ---
	engine_get_device :: proc(pEngine: ^engine) -> ^device ---
	engine_get_log :: proc(pEngine: ^engine) -> ^log ---
	engine_get_endpoint :: proc(pEngine: ^engine) -> ^ma_node ---
	engine_get_time_in_pcm_frames :: proc(pEngine: ^engine) -> uint64 ---
	engine_get_time_in_milliseconds :: proc(pEngine: ^engine) -> uint64 ---
	engine_set_time_in_pcm_frames :: proc(pEngine: ^engine, globalTime: uint64) -> result ---
	engine_set_time_in_milliseconds :: proc(pEngine: ^engine, globalTime: uint64) -> result ---
	engine_get_time :: proc(pEngine: ^engine) -> uint64 ---
	engine_set_time :: proc(pEngine: ^engine, globalTime: uint64) -> result ---
	engine_get_channels :: proc(pEngine: ^engine) -> uint32 ---
	engine_get_sample_rate :: proc(pEngine: ^engine) -> uint32 ---
	engine_start :: proc(pEngine: ^engine) -> result ---
	engine_stop :: proc(pEngine: ^engine) -> result ---
	engine_set_volume :: proc(pEngine: ^engine, volume: f32) -> result ---
	engine_get_volume :: proc(pEngine: ^engine) -> f32 ---
	engine_set_gain_db :: proc(pEngine: ^engine, gainDB: f32) -> result ---
	engine_get_gain_db :: proc(pEngine: ^engine) -> f32 ---
	engine_get_listener_count :: proc(pEngine: ^engine) -> uint32 ---
	engine_find_closest_listener :: proc(pEngine: ^engine, absolutePosX: f32, absolutePosY: f32, absolutePosZ: f32) -> uint32 ---
	engine_listener_set_position :: proc(pEngine: ^engine, listenerIndex: uint32, x: f32, y: f32, z: f32) ---
	engine_listener_get_position :: proc(pEngine: ^engine, listenerIndex: uint32) -> vec3f ---
	engine_listener_set_direction :: proc(pEngine: ^engine, listenerIndex: uint32, x: f32, y: f32, z: f32) ---
	engine_listener_get_direction :: proc(pEngine: ^engine, listenerIndex: uint32) -> vec3f ---
	engine_listener_set_velocity :: proc(pEngine: ^engine, listenerIndex: uint32, x: f32, y: f32, z: f32) ---
	engine_listener_get_velocity :: proc(pEngine: ^engine, listenerIndex: uint32) -> vec3f ---
	engine_listener_set_cone :: proc(pEngine: ^engine, listenerIndex: uint32, innerAngleInRadians: f32, outerAngleInRadians: f32, outerGain: f32) ---
	engine_listener_get_cone :: proc(pEngine: ^engine, listenerIndex: uint32, pInnerAngleInRadians: ^f32, pOuterAngleInRadians: ^f32, pOuterGain: ^f32) ---
	engine_listener_set_world_up :: proc(pEngine: ^engine, listenerIndex: uint32, x: f32, y: f32, z: f32) ---
	engine_listener_get_world_up :: proc(pEngine: ^engine, listenerIndex: uint32) -> vec3f ---
	engine_listener_set_enabled :: proc(pEngine: ^engine, listenerIndex: uint32, isEnabled: bool32) ---
	engine_listener_is_enabled :: proc(pEngine: ^engine, listenerIndex: uint32) -> bool32 ---
	engine_play_sound_ex :: proc(pEngine: ^engine, pFilePath: cstring, pNode: ^ma_node, nodeInputBusIndex: uint32) -> result ---
	engine_play_sound :: proc(pEngine: ^engine, pFilePath: cstring, pGroup: ^sound_group) -> result ---
	sound_init_from_file :: proc(pEngine: ^engine, pFilePath: cstring, flags: uint32, pGroup: ^sound_group, pDoneFence: ^fence, pSound: ^sound) -> result ---
	sound_init_from_file_w :: proc(pEngine: ^engine, pFilePath: ^i32, flags: uint32, pGroup: ^sound_group, pDoneFence: ^fence, pSound: ^sound) -> result ---
	sound_init_copy :: proc(pEngine: ^engine, pExistingSound: ^sound, flags: uint32, pGroup: ^sound_group, pSound: ^sound) -> result ---
	sound_init_from_data_source :: proc(pEngine: ^engine, pDataSource: ^ma_data_source, flags: uint32, pGroup: ^sound_group, pSound: ^sound) -> result ---
	sound_init_ex :: proc(pEngine: ^engine, pConfig: ^sound_config, pSound: ^sound) -> result ---
	sound_uninit :: proc(pSound: ^sound) ---
	sound_get_engine :: proc(pSound: ^sound) -> ^engine ---
	sound_get_data_source :: proc(pSound: ^sound) -> ^ma_data_source ---
	sound_start :: proc(pSound: ^sound) -> result ---
	sound_stop :: proc(pSound: ^sound) -> result ---
	sound_stop_with_fade_in_pcm_frames :: proc(pSound: ^sound, fadeLengthInFrames: uint64) -> result ---
	sound_stop_with_fade_in_milliseconds :: proc(pSound: ^sound, fadeLengthInFrames: uint64) -> result ---
	sound_reset_start_time :: proc(pSound: ^sound) ---
	sound_reset_stop_time :: proc(pSound: ^sound) ---
	sound_reset_fade :: proc(pSound: ^sound) ---
	sound_reset_stop_time_and_fade :: proc(pSound: ^sound) ---
	sound_set_volume :: proc(pSound: ^sound, volume: f32) ---
	sound_get_volume :: proc(pSound: ^sound) -> f32 ---
	sound_set_pan :: proc(pSound: ^sound, pan: f32) ---
	sound_get_pan :: proc(pSound: ^sound) -> f32 ---
	sound_set_pan_mode :: proc(pSound: ^sound, panMode: pan_mode) ---
	sound_get_pan_mode :: proc(pSound: ^sound) -> pan_mode ---
	sound_set_pitch :: proc(pSound: ^sound, pitch: f32) ---
	sound_get_pitch :: proc(pSound: ^sound) -> f32 ---
	sound_set_spatialization_enabled :: proc(pSound: ^sound, enabled: bool32) ---
	sound_is_spatialization_enabled :: proc(pSound: ^sound) -> bool32 ---
	sound_set_pinned_listener_index :: proc(pSound: ^sound, listenerIndex: uint32) ---
	sound_get_pinned_listener_index :: proc(pSound: ^sound) -> uint32 ---
	sound_get_listener_index :: proc(pSound: ^sound) -> uint32 ---
	sound_get_direction_to_listener :: proc(pSound: ^sound) -> vec3f ---
	sound_set_position :: proc(pSound: ^sound, x: f32, y: f32, z: f32) ---
	sound_get_position :: proc(pSound: ^sound) -> vec3f ---
	sound_set_direction :: proc(pSound: ^sound, x: f32, y: f32, z: f32) ---
	sound_get_direction :: proc(pSound: ^sound) -> vec3f ---
	sound_set_velocity :: proc(pSound: ^sound, x: f32, y: f32, z: f32) ---
	sound_get_velocity :: proc(pSound: ^sound) -> vec3f ---
	sound_set_attenuation_model :: proc(pSound: ^sound, attenuationModel: attenuation_model) ---
	sound_get_attenuation_model :: proc(pSound: ^sound) -> attenuation_model ---
	sound_set_positioning :: proc(pSound: ^sound, positioning: positioning) ---
	sound_get_positioning :: proc(pSound: ^sound) -> positioning ---
	sound_set_rolloff :: proc(pSound: ^sound, rolloff: f32) ---
	sound_get_rolloff :: proc(pSound: ^sound) -> f32 ---
	sound_set_min_gain :: proc(pSound: ^sound, minGain: f32) ---
	sound_get_min_gain :: proc(pSound: ^sound) -> f32 ---
	sound_set_max_gain :: proc(pSound: ^sound, maxGain: f32) ---
	sound_get_max_gain :: proc(pSound: ^sound) -> f32 ---
	sound_set_min_distance :: proc(pSound: ^sound, minDistance: f32) ---
	sound_get_min_distance :: proc(pSound: ^sound) -> f32 ---
	sound_set_max_distance :: proc(pSound: ^sound, maxDistance: f32) ---
	sound_get_max_distance :: proc(pSound: ^sound) -> f32 ---
	sound_set_cone :: proc(pSound: ^sound, innerAngleInRadians: f32, outerAngleInRadians: f32, outerGain: f32) ---
	sound_get_cone :: proc(pSound: ^sound, pInnerAngleInRadians: ^f32, pOuterAngleInRadians: ^f32, pOuterGain: ^f32) ---
	sound_set_doppler_factor :: proc(pSound: ^sound, dopplerFactor: f32) ---
	sound_get_doppler_factor :: proc(pSound: ^sound) -> f32 ---
	sound_set_directional_attenuation_factor :: proc(pSound: ^sound, directionalAttenuationFactor: f32) ---
	sound_get_directional_attenuation_factor :: proc(pSound: ^sound) -> f32 ---
	sound_set_fade_in_pcm_frames :: proc(pSound: ^sound, volumeBeg: f32, volumeEnd: f32, fadeLengthInFrames: uint64) ---
	sound_set_fade_in_milliseconds :: proc(pSound: ^sound, volumeBeg: f32, volumeEnd: f32, fadeLengthInMilliseconds: uint64) ---
	sound_set_fade_start_in_pcm_frames :: proc(pSound: ^sound, volumeBeg: f32, volumeEnd: f32, fadeLengthInFrames: uint64, absoluteGlobalTimeInFrames: uint64) ---
	sound_set_fade_start_in_milliseconds :: proc(pSound: ^sound, volumeBeg: f32, volumeEnd: f32, fadeLengthInMilliseconds: uint64, absoluteGlobalTimeInMilliseconds: uint64) ---
	sound_get_current_fade_volume :: proc(pSound: ^sound) -> f32 ---
	sound_set_start_time_in_pcm_frames :: proc(pSound: ^sound, absoluteGlobalTimeInFrames: uint64) ---
	sound_set_start_time_in_milliseconds :: proc(pSound: ^sound, absoluteGlobalTimeInMilliseconds: uint64) ---
	sound_set_stop_time_in_pcm_frames :: proc(pSound: ^sound, absoluteGlobalTimeInFrames: uint64) ---
	sound_set_stop_time_in_milliseconds :: proc(pSound: ^sound, absoluteGlobalTimeInMilliseconds: uint64) ---
	sound_set_stop_time_with_fade_in_pcm_frames :: proc(pSound: ^sound, stopAbsoluteGlobalTimeInFrames: uint64, fadeLengthInFrames: uint64) ---
	sound_set_stop_time_with_fade_in_milliseconds :: proc(pSound: ^sound, stopAbsoluteGlobalTimeInMilliseconds: uint64, fadeLengthInMilliseconds: uint64) ---
	sound_is_playing :: proc(pSound: ^sound) -> bool32 ---
	sound_get_time_in_pcm_frames :: proc(pSound: ^sound) -> uint64 ---
	sound_get_time_in_milliseconds :: proc(pSound: ^sound) -> uint64 ---
	sound_set_looping :: proc(pSound: ^sound, isLooping: bool32) ---
	sound_is_looping :: proc(pSound: ^sound) -> bool32 ---
	sound_at_end :: proc(pSound: ^sound) -> bool32 ---
	sound_seek_to_pcm_frame :: proc(pSound: ^sound, frameIndex: uint64) -> result ---
	sound_seek_to_second :: proc(pSound: ^sound, seekPointInSeconds: f32) -> result ---
	sound_get_data_format :: proc(pSound: ^sound, pFormat: ^format, pChannels: ^uint32, pSampleRate: ^uint32, pChannelMap: ^channel, channelMapCap: uint) -> result ---
	sound_get_cursor_in_pcm_frames :: proc(pSound: ^sound, pCursor: ^uint64) -> result ---
	sound_get_length_in_pcm_frames :: proc(pSound: ^sound, pLength: ^uint64) -> result ---
	sound_get_cursor_in_seconds :: proc(pSound: ^sound, pCursor: ^f32) -> result ---
	sound_get_length_in_seconds :: proc(pSound: ^sound, pLength: ^f32) -> result ---
	sound_set_end_callback :: proc(pSound: ^sound, callback: sound_end_proc, pUserData: rawptr) -> result ---
	sound_group_init :: proc(pEngine: ^engine, flags: uint32, pParentGroup: ^sound_group, pGroup: ^sound_group) -> result ---
	sound_group_init_ex :: proc(pEngine: ^engine, pConfig: ^sound_group_config, pGroup: ^sound_group) -> result ---
	sound_group_uninit :: proc(pGroup: ^sound_group) ---
	sound_group_get_engine :: proc(pGroup: ^sound_group) -> ^engine ---
	sound_group_start :: proc(pGroup: ^sound_group) -> result ---
	sound_group_stop :: proc(pGroup: ^sound_group) -> result ---
	sound_group_set_volume :: proc(pGroup: ^sound_group, volume: f32) ---
	sound_group_get_volume :: proc(pGroup: ^sound_group) -> f32 ---
	sound_group_set_pan :: proc(pGroup: ^sound_group, pan: f32) ---
	sound_group_get_pan :: proc(pGroup: ^sound_group) -> f32 ---
	sound_group_set_pan_mode :: proc(pGroup: ^sound_group, panMode: pan_mode) ---
	sound_group_get_pan_mode :: proc(pGroup: ^sound_group) -> pan_mode ---
	sound_group_set_pitch :: proc(pGroup: ^sound_group, pitch: f32) ---
	sound_group_get_pitch :: proc(pGroup: ^sound_group) -> f32 ---
	sound_group_set_spatialization_enabled :: proc(pGroup: ^sound_group, enabled: bool32) ---
	sound_group_is_spatialization_enabled :: proc(pGroup: ^sound_group) -> bool32 ---
	sound_group_set_pinned_listener_index :: proc(pGroup: ^sound_group, listenerIndex: uint32) ---
	sound_group_get_pinned_listener_index :: proc(pGroup: ^sound_group) -> uint32 ---
	sound_group_get_listener_index :: proc(pGroup: ^sound_group) -> uint32 ---
	sound_group_get_direction_to_listener :: proc(pGroup: ^sound_group) -> vec3f ---
	sound_group_set_position :: proc(pGroup: ^sound_group, x: f32, y: f32, z: f32) ---
	sound_group_get_position :: proc(pGroup: ^sound_group) -> vec3f ---
	sound_group_set_direction :: proc(pGroup: ^sound_group, x: f32, y: f32, z: f32) ---
	sound_group_get_direction :: proc(pGroup: ^sound_group) -> vec3f ---
	sound_group_set_velocity :: proc(pGroup: ^sound_group, x: f32, y: f32, z: f32) ---
	sound_group_get_velocity :: proc(pGroup: ^sound_group) -> vec3f ---
	sound_group_set_attenuation_model :: proc(pGroup: ^sound_group, attenuationModel: attenuation_model) ---
	sound_group_get_attenuation_model :: proc(pGroup: ^sound_group) -> attenuation_model ---
	sound_group_set_positioning :: proc(pGroup: ^sound_group, positioning: positioning) ---
	sound_group_get_positioning :: proc(pGroup: ^sound_group) -> positioning ---
	sound_group_set_rolloff :: proc(pGroup: ^sound_group, rolloff: f32) ---
	sound_group_get_rolloff :: proc(pGroup: ^sound_group) -> f32 ---
	sound_group_set_min_gain :: proc(pGroup: ^sound_group, minGain: f32) ---
	sound_group_get_min_gain :: proc(pGroup: ^sound_group) -> f32 ---
	sound_group_set_max_gain :: proc(pGroup: ^sound_group, maxGain: f32) ---
	sound_group_get_max_gain :: proc(pGroup: ^sound_group) -> f32 ---
	sound_group_set_min_distance :: proc(pGroup: ^sound_group, minDistance: f32) ---
	sound_group_get_min_distance :: proc(pGroup: ^sound_group) -> f32 ---
	sound_group_set_max_distance :: proc(pGroup: ^sound_group, maxDistance: f32) ---
	sound_group_get_max_distance :: proc(pGroup: ^sound_group) -> f32 ---
	sound_group_set_cone :: proc(pGroup: ^sound_group, innerAngleInRadians: f32, outerAngleInRadians: f32, outerGain: f32) ---
	sound_group_get_cone :: proc(pGroup: ^sound_group, pInnerAngleInRadians: ^f32, pOuterAngleInRadians: ^f32, pOuterGain: ^f32) ---
	sound_group_set_doppler_factor :: proc(pGroup: ^sound_group, dopplerFactor: f32) ---
	sound_group_get_doppler_factor :: proc(pGroup: ^sound_group) -> f32 ---
	sound_group_set_directional_attenuation_factor :: proc(pGroup: ^sound_group, directionalAttenuationFactor: f32) ---
	sound_group_get_directional_attenuation_factor :: proc(pGroup: ^sound_group) -> f32 ---
	sound_group_set_fade_in_pcm_frames :: proc(pGroup: ^sound_group, volumeBeg: f32, volumeEnd: f32, fadeLengthInFrames: uint64) ---
	sound_group_set_fade_in_milliseconds :: proc(pGroup: ^sound_group, volumeBeg: f32, volumeEnd: f32, fadeLengthInMilliseconds: uint64) ---
	sound_group_get_current_fade_volume :: proc(pGroup: ^sound_group) -> f32 ---
	sound_group_set_start_time_in_pcm_frames :: proc(pGroup: ^sound_group, absoluteGlobalTimeInFrames: uint64) ---
	sound_group_set_start_time_in_milliseconds :: proc(pGroup: ^sound_group, absoluteGlobalTimeInMilliseconds: uint64) ---
	sound_group_set_stop_time_in_pcm_frames :: proc(pGroup: ^sound_group, absoluteGlobalTimeInFrames: uint64) ---
	sound_group_set_stop_time_in_milliseconds :: proc(pGroup: ^sound_group, absoluteGlobalTimeInMilliseconds: uint64) ---
	sound_group_is_playing :: proc(pGroup: ^sound_group) -> bool32 ---
	sound_group_get_time_in_pcm_frames :: proc(pGroup: ^sound_group) -> uint64 ---
}
