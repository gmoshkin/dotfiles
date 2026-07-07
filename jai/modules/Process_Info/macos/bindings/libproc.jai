//
// This file was auto-generated using the following command:
//
// jai jai/modules/Process_Info/macos/generate.jai
//



SIDL :: 1;
SRUN :: 2;
SSLEEP :: 3;
SSTOP :: 4;
SZOMB :: 5;

P_ADVLOCK :: 0x00000001;
P_CONTROLT :: 0x00000002;
P_LP64 :: 0x00000004;
P_NOCLDSTOP :: 0x00000008;

P_PPWAIT :: 0x00000010;
P_PROFIL :: 0x00000020;
P_SELECT :: 0x00000040;
P_CONTINUED :: 0x00000080;

P_SUGID :: 0x00000100;
P_SYSTEM :: 0x00000200;
P_TIMEOUT :: 0x00000400;

P_DISABLE_ASLR :: 0x00001000;
P_WEXIT :: 0x00002000;
P_EXEC :: 0x00004000;

P_OWEUPC :: 0x00008000;

P_AFFINITY :: 0x00010000;
P_TRANSLATED :: 0x00020000;
P_CLASSIC :: P_TRANSLATED;

P_DELAYIDLESLEEP :: 0x00040000;
P_CHECKOPENEVT :: 0x00080000;

P_DEPENDENCY_CAPABLE :: 0x00100000;
P_REBOOT :: 0x00200000;
P_RESV6 :: 0x00400000;
P_RESV7 :: 0x00800000;

P_THCWD :: 0x01000000;
P_RESV9 :: 0x02000000;
P_ADOPTPERSONA :: 0x04000000;
P_RESV11 :: 0x08000000;

P_NOSHLIB :: 0x10000000;

P_FORCEQUOTA :: 0x20000000;
P_NOCLDWAIT :: 0x40000000;
P_NOREMOTEHANG :: 0x80000000;

P_INMEM :: 0;
P_NOSWAP :: 0;
P_PHYSIO :: 0;
P_FSTRACE :: 0;
P_SSTEP :: 0;

P_DIRTY_TRACK :: 0x00000001;
P_DIRTY_ALLOW_IDLE_EXIT :: 0x00000002;
P_DIRTY_DEFER :: 0x00000004;
P_DIRTY :: 0x00000008;
P_DIRTY_SHUTDOWN :: 0x00000010;
P_DIRTY_TERMINATED :: 0x00000020;
P_DIRTY_BUSY :: 0x00000040;
P_DIRTY_MARKED :: 0x00000080;
P_DIRTY_AGING_IN_PROGRESS :: 0x00000100;
P_DIRTY_LAUNCH_IN_PROGRESS :: 0x00000200;
P_DIRTY_DEFER_ALWAYS :: 0x00000400;

P_DIRTY_SHUTDOWN_ON_CLEAN :: 0x00000800;
P_DIRTY_IM_NEW_HERE :: 0x00001000;

P_DIRTY_IS_DIRTY :: P_DIRTY | P_DIRTY_SHUTDOWN;
P_DIRTY_IDLE_EXIT_ENABLED :: P_DIRTY_TRACK|P_DIRTY_ALLOW_IDLE_EXIT;

PROC_ALL_PIDS :: 1;
PROC_PGRP_ONLY :: 2;
PROC_TTY_ONLY :: 3;
PROC_UID_ONLY :: 4;
PROC_RUID_ONLY :: 5;
PROC_PPID_ONLY :: 6;
PROC_KDBG_ONLY :: 7;

PROC_FLAG_SYSTEM :: 1;
PROC_FLAG_TRACED :: 2;
PROC_FLAG_INEXIT :: 4;
PROC_FLAG_PPWAIT :: 8;
PROC_FLAG_LP64 :: 0x10;
PROC_FLAG_SLEADER :: 0x20;
PROC_FLAG_CTTY :: 0x40;
PROC_FLAG_CONTROLT :: 0x80;
PROC_FLAG_THCWD :: 0x100;

PROC_FLAG_PC_THROTTLE :: 0x200;
PROC_FLAG_PC_SUSP :: 0x400;
PROC_FLAG_PC_KILL :: 0x600;
PROC_FLAG_PC_MASK :: 0x600;

PROC_FLAG_PA_THROTTLE :: 0x800;
PROC_FLAG_PA_SUSP :: 0x1000;
PROC_FLAG_PSUGID :: 0x2000;
PROC_FLAG_EXEC :: 0x4000;

MAXTHREADNAMESIZE :: 64;

PROC_REGION_SUBMAP :: 1;
PROC_REGION_SHARED :: 2;

SM_COW :: 1;
SM_PRIVATE :: 2;
SM_EMPTY :: 3;
SM_SHARED :: 4;
SM_TRUESHARED :: 5;
SM_PRIVATE_ALIASED :: 6;
SM_SHARED_ALIASED :: 7;
SM_LARGE_PAGE :: 8;

TH_STATE_RUNNING :: 1;
TH_STATE_STOPPED :: 2;
TH_STATE_WAITING :: 3;
TH_STATE_UNINTERRUPTIBLE :: 4;

TH_STATE_HALTED :: 5;

TH_FLAGS_SWAPPED :: 0x1;
TH_FLAGS_IDLE :: 0x2;

WQ_EXCEEDED_CONSTRAINED_THREAD_LIMIT :: 0x1;
WQ_EXCEEDED_TOTAL_THREAD_LIMIT :: 0x2;
WQ_FLAGS_AVAILABLE :: 0x4;

WQ_EXCEEDED_COOPERATIVE_THREAD_LIMIT :: 0x8;

WQ_EXCEEDED_ACTIVE_CONSTRAINED_THREAD_LIMIT :: 0x10;

PROC_FP_SHARED :: 1;
PROC_FP_CLEXEC :: 2;
PROC_FP_GUARDED :: 4;
PROC_FP_CLFORK :: 8;

PROC_FI_GUARD_CLOSE :: 1 << 0;
PROC_FI_GUARD_DUP :: 1 << 1;
PROC_FI_GUARD_SOCKET_IPC :: 1 << 2;
PROC_FI_GUARD_FILEPORT :: 1 << 3;

INI_IPV4 :: 0x1;
INI_IPV6 :: 0x2;

TSI_T_REXMT :: 0;
TSI_T_PERSIST :: 1;
TSI_T_KEEP :: 2;
TSI_T_2MSL :: 3;
TSI_T_NTIMERS :: 4;

TSI_S_CLOSED :: 0;
TSI_S_LISTEN :: 1;
TSI_S_SYN_SENT :: 2;
TSI_S_SYN_RECEIVED :: 3;
TSI_S_ESTABLISHED :: 4;
TSI_S__CLOSE_WAIT :: 5;
TSI_S_FIN_WAIT_1 :: 6;
TSI_S_CLOSING :: 7;
TSI_S_LAST_ACK :: 8;
TSI_S_FIN_WAIT_2 :: 9;
TSI_S_TIME_WAIT :: 10;
TSI_S_RESERVED :: 11;

SOI_S_NOFDREF :: 0x0001;
SOI_S_ISCONNECTED :: 0x0002;
SOI_S_ISCONNECTING :: 0x0004;
SOI_S_ISDISCONNECTING :: 0x0008;
SOI_S_CANTSENDMORE :: 0x0010;
SOI_S_CANTRCVMORE :: 0x0020;
SOI_S_RCVATMARK :: 0x0040;
SOI_S_PRIV :: 0x0080;
SOI_S_NBIO :: 0x0100;
SOI_S_ASYNC :: 0x0200;
SOI_S_INCOMP :: 0x0800;
SOI_S_COMP :: 0x1000;
SOI_S_ISDISCONNECTED :: 0x2000;
SOI_S_DRAINING :: 0x4000;

PROC_KQUEUE_SELECT :: 0x0001;
PROC_KQUEUE_SLEEP :: 0x0002;
PROC_KQUEUE_32 :: 0x0008;
PROC_KQUEUE_64 :: 0x0010;
PROC_KQUEUE_QOS :: 0x0020;

PROX_FDTYPE_ATALK :: 0;
PROX_FDTYPE_VNODE :: 1;
PROX_FDTYPE_SOCKET :: 2;
PROX_FDTYPE_PSHM :: 3;
PROX_FDTYPE_PSEM :: 4;
PROX_FDTYPE_KQUEUE :: 5;
PROX_FDTYPE_PIPE :: 6;
PROX_FDTYPE_FSEVENTS :: 7;
PROX_FDTYPE_NETPOLICY :: 9;
PROX_FDTYPE_CHANNEL :: 10;
PROX_FDTYPE_NEXUS :: 11;

PROC_CHANNEL_TYPE_USER_PIPE :: 0;
PROC_CHANNEL_TYPE_KERNEL_PIPE :: 1;
PROC_CHANNEL_TYPE_NET_IF :: 2;
PROC_CHANNEL_TYPE_FLOW_SWITCH :: 3;

PROC_CHANNEL_FLAGS_MONITOR_TX :: 0x1;
PROC_CHANNEL_FLAGS_MONITOR_RX :: 0x2;
PROC_CHANNEL_FLAGS_MONITOR_NO_COPY :: 0x4;
PROC_CHANNEL_FLAGS_EXCLUSIVE :: 0x10;
PROC_CHANNEL_FLAGS_USER_PACKET_POOL :: 0x20;
PROC_CHANNEL_FLAGS_DEFUNCT_OK :: 0x40;
PROC_CHANNEL_FLAGS_LOW_LATENCY :: 0x80;
PROC_CHANNEL_FLAGS_MONITOR :: PROC_CHANNEL_FLAGS_MONITOR_TX | PROC_CHANNEL_FLAGS_MONITOR_RX;

PROC_PIDLISTFDS :: 1;

PROC_PIDTASKALLINFO :: 2;

PROC_PIDTBSDINFO :: 3;

PROC_PIDTASKINFO :: 4;

PROC_PIDTHREADINFO :: 5;

PROC_PIDLISTTHREADS :: 6;

PROC_PIDREGIONINFO :: 7;

PROC_PIDREGIONPATHINFO :: 8;

PROC_PIDVNODEPATHINFO :: 9;

PROC_PIDTHREADPATHINFO :: 10;

PROC_PIDPATHINFO :: 11;

PROC_PIDWORKQUEUEINFO :: 12;

PROC_PIDT_SHORTBSDINFO :: 13;

PROC_PIDLISTFILEPORTS :: 14;

PROC_PIDTHREADID64INFO :: 15;

PROC_PID_RUSAGE :: 16;
PROC_PID_RUSAGE_SIZE :: 0;

PROC_PIDARCHINFO :: 19;

PROC_PIDFDVNODEINFO :: 1;

PROC_PIDFDVNODEPATHINFO :: 2;

PROC_PIDFDSOCKETINFO :: 3;

PROC_PIDFDPSEMINFO :: 4;

PROC_PIDFDPSHMINFO :: 5;

PROC_PIDFDPIPEINFO :: 6;

PROC_PIDFDKQUEUEINFO :: 7;

PROC_PIDFDATALKINFO :: 8;

PROC_PIDFDCHANNELINFO :: 10;

PROC_PIDFILEPORTVNODEPATHINFO :: 2;

PROC_PIDFILEPORTSOCKETINFO :: 3;

PROC_PIDFILEPORTPSHMINFO :: 5;

PROC_PIDFILEPORTPIPEINFO :: 6;

PROC_SELFSET_PCONTROL :: 1;

PROC_SELFSET_THREADNAME :: 2;
PROC_SELFSET_THREADNAME_SIZE :: MAXTHREADNAMESIZE -1;

PROC_SELFSET_VMRSRCOWNER :: 3;

PROC_SELFSET_DELAYIDLESLEEP :: 4;

PROC_DIRTYCONTROL_TRACK :: 1;
PROC_DIRTYCONTROL_SET :: 2;
PROC_DIRTYCONTROL_GET :: 3;
PROC_DIRTYCONTROL_CLEAR :: 4;

PROC_DIRTY_TRACK :: 0x1;
PROC_DIRTY_ALLOW_IDLE_EXIT :: 0x2;
PROC_DIRTY_DEFER :: 0x4;
PROC_DIRTY_LAUNCH_IN_PROGRESS :: 0x8;
PROC_DIRTY_DEFER_ALWAYS :: 0x10;
PROC_DIRTY_SHUTDOWN_ON_CLEAN :: 0x20;

PROC_DIRTY_TRACKED :: 0x1;
PROC_DIRTY_ALLOWS_IDLE_EXIT :: 0x2;
PROC_DIRTY_IS_DIRTY :: 0x4;
PROC_DIRTY_LAUNCH_IS_IN_PROGRESS :: 0x8;

PROC_UDATA_INFO_GET :: 1;
PROC_UDATA_INFO_SET :: 2;

PROC_LISTPIDSPATH_PATH_IS_VOLUME :: 1;

PROC_LISTPIDSPATH_EXCLUDE_EVTONLY :: 2;

PROC_SETPC_NONE :: 0;
PROC_SETPC_THROTTLEMEM :: 1;
PROC_SETPC_SUSPEND :: 2;
PROC_SETPC_TERMINATE :: 3;

PROC_CSM_ALL :: 0x0001;
PROC_CSM_NOSMT :: 0x0002;
PROC_CSM_TECS :: 0x0004;

in_addr_t :: u32;

proc_ident :: struct {}

fsid :: struct {
    val: [2] s32;
}
fsid_t :: fsid;

vnode :: struct {}

sa_family_t :: u8;

sockaddr_un :: struct {
    sun_len:    u8;
    sun_family: sa_family_t;
    sun_path:   [104] u8;
}

in_addr :: struct {
    s_addr: in_addr_t;
}

in6_addr :: struct {
    __u6_addr: struct {
        __u6_addr8: [16] u8;

        #overlay (__u6_addr8) __u6_addr16: [8] u16;
        #overlay (__u6_addr8) __u6_addr32: [4] u32;
    };
}

cpu_type_t :: s32;
cpu_subtype_t :: s32;

proc_bsdinfo :: struct {
    pbi_flags:        u32; /* 64bit; emulated etc */
    pbi_status:       u32;
    pbi_xstatus:      u32;
    pbi_pid:          u32;
    pbi_ppid:         u32;
    pbi_uid:          uid_t;
    pbi_gid:          gid_t;
    pbi_ruid:         uid_t;
    pbi_rgid:         gid_t;
    pbi_svuid:        uid_t;
    pbi_svgid:        gid_t;
    rfu_1:            u32; /* reserved */
    pbi_comm:         [16] u8;
    pbi_name:         [32] u8; /* empty if no name is registered */
    pbi_nfiles:       u32;
    pbi_pgid:         u32;
    pbi_pjobc:        u32;
    e_tdev:           u32; /* controlling tty dev */
    e_tpgid:          u32; /* tty process group id */
    pbi_nice:         s32;
    pbi_start_tvsec:  u64;
    pbi_start_tvusec: u64;
}

proc_bsdshortinfo :: struct {
    pbsi_pid:    u32; /* process id */
    pbsi_ppid:   u32; /* process parent id */
    pbsi_pgid:   u32; /* process perp id */
    pbsi_status: u32; /* p_stat value, SZOMB, SRUN, etc */
    pbsi_comm:   [16] u8; /* upto 16 characters of process name */
    pbsi_flags:  u32; /* 64bit; emulated etc */
    pbsi_uid:    uid_t; /* current uid on process */
    pbsi_gid:    gid_t; /* current gid on process */
    pbsi_ruid:   uid_t; /* current ruid on process */
    pbsi_rgid:   gid_t; /* current tgid on process */
    pbsi_svuid:  uid_t; /* current svuid on process */
    pbsi_svgid:  gid_t; /* current svgid on process */
    pbsi_rfu:    u32; /* reserved for future use*/
}

proc_taskinfo :: struct {
    pti_virtual_size:      u64; /* virtual memory size (bytes) */
    pti_resident_size:     u64; /* resident memory size (bytes) */
    pti_total_user:        u64; /* total time */
    pti_total_system:      u64;
    pti_threads_user:      u64; /* existing threads only */
    pti_threads_system:    u64;
    pti_policy:            s32; /* default policy for new threads */
    pti_faults:            s32; /* number of page faults */
    pti_pageins:           s32; /* number of actual pageins */
    pti_cow_faults:        s32; /* number of copy-on-write faults */
    pti_messages_sent:     s32; /* number of messages sent */
    pti_messages_received: s32; /* number of messages received */
    pti_syscalls_mach:     s32; /* number of mach system calls */
    pti_syscalls_unix:     s32; /* number of unix system calls */
    pti_csw:               s32; /* number of context switches */
    pti_threadnum:         s32; /* number of threads in the task */
    pti_numrunning:        s32; /* number of running threads */
    pti_priority:          s32; /* task priority*/
}

proc_taskallinfo :: struct {
    pbsd:   proc_bsdinfo;
    ptinfo: proc_taskinfo;
}

proc_threadinfo :: struct {
    pth_user_time:   u64; /* user run time */
    pth_system_time: u64; /* system run time */
    pth_cpu_usage:   s32; /* scaled cpu usage percentage */
    pth_policy:      s32; /* scheduling policy in effect */
    pth_run_state:   s32; /* run state (see below) */
    pth_flags:       s32; /* various flags (see below) */
    pth_sleep_time:  s32; /* number of seconds that thread */
    pth_curpri:      s32; /* cur priority*/
    pth_priority:    s32; /*  priority*/
    pth_maxpriority: s32; /* max priority*/
    pth_name:        [64] u8; /* thread name, if any */
}

proc_regioninfo :: struct {
    pri_protection:               u32;
    pri_max_protection:           u32;
    pri_inheritance:              u32;
    pri_flags:                    u32; /* shared, external pager, is submap */
    pri_offset:                   u64;
    pri_behavior:                 u32;
    pri_user_wired_count:         u32;
    pri_user_tag:                 u32;
    pri_pages_resident:           u32;
    pri_pages_shared_now_private: u32;
    pri_pages_swapped_out:        u32;
    pri_pages_dirtied:            u32;
    pri_ref_count:                u32;
    pri_shadow_depth:             u32;
    pri_share_mode:               u32;
    pri_private_pages_resident:   u32;
    pri_shared_pages_resident:    u32;
    pri_obj_id:                   u32;
    pri_depth:                    u32;
    pri_address:                  u64;
    pri_size:                     u64;
}

proc_workqueueinfo :: struct {
    pwq_nthreads:       u32; /* total number of workqueue threads */
    pwq_runthreads:     u32; /* total number of running workqueue threads */
    pwq_blockedthreads: u32; /* total number of blocked workqueue threads */
    pwq_state:          u32;
}

proc_fileinfo :: struct {
    fi_openflags:  u32;
    fi_status:     u32;
    fi_offset:     s64;
    fi_type:       s32;
    fi_guardflags: u32;
}

proc_exitreasonbasicinfo :: struct {
    beri_namespace:       u32 #align 1;
    beri_code:            u64 #align 1;
    beri_flags:           u64 #align 1;
    beri_reason_buf_size: u32 #align 1;
}

proc_exitreasoninfo :: struct {
    eri_namespace:       u32 #align 1;
    eri_code:            u64 #align 1;
    eri_flags:           u64 #align 1;
    eri_reason_buf_size: u32 #align 1;
    eri_kcd_buf:         u64 #align 1;
}

/*
* A copy of stat64 with static sized fields.
*/
vinfo_stat :: struct {
    vst_dev:           u32; /* [XSI] ID of device containing file */
    vst_mode:          u16; /* [XSI] Mode of file (see below) */
    vst_nlink:         u16; /* [XSI] Number of hard links */
    vst_ino:           u64; /* [XSI] File serial number */
    vst_uid:           uid_t; /* [XSI] User ID of the file */
    vst_gid:           gid_t; /* [XSI] Group ID of the file */
    vst_atime:         s64; /* [XSI] Time of last access */
    vst_atimensec:     s64; /* nsec of last access */
    vst_mtime:         s64; /* [XSI] Last data modification time */
    vst_mtimensec:     s64; /* last data modification nsec */
    vst_ctime:         s64; /* [XSI] Time of last status change */
    vst_ctimensec:     s64; /* nsec of last status change */
    vst_birthtime:     s64; /*  File creation time(birth)  */
    vst_birthtimensec: s64; /* nsec of File creation time */
    vst_size:          s64; /* [XSI] file size, in bytes */
    vst_blocks:        s64; /* [XSI] blocks allocated for file */
    vst_blksize:       s32; /* [XSI] optimal blocksize for I/O */
    vst_flags:         u32; /* user defined flags for file */
    vst_gen:           u32; /* file generation number */
    vst_rdev:          u32; /* [XSI] Device ID */
    vst_qspare:        [2] s64; /* RESERVED: DO NOT USE! */
}

vnode_info :: struct {
    vi_stat: vinfo_stat;
    vi_type: s32;
    vi_pad:  s32;
    vi_fsid: fsid_t;
}

vnode_info_path :: struct {
    vip_vi:   vnode_info;
    vip_path: [1024] u8; /* tail end of it  */
}

vnode_fdinfo :: struct {
    pfi: proc_fileinfo;
    pvi: vnode_info;
}

vnode_fdinfowithpath :: struct {
    pfi:  proc_fileinfo;
    pvip: vnode_info_path;
}

proc_regionwithpathinfo :: struct {
    prp_prinfo: proc_regioninfo;
    prp_vip:    vnode_info_path;
}

proc_regionpath :: struct {
    prpo_addr:         u64;
    prpo_regionlength: u64;
    prpo_path:         [1024] u8;
}

proc_vnodepathinfo :: struct {
    pvi_cdir: vnode_info_path;
    pvi_rdir: vnode_info_path;
}

proc_threadwithpathinfo :: struct {
    pt:   proc_threadinfo;
    pvip: vnode_info_path;
}

proc_archinfo :: struct {
    p_cputype:    cpu_type_t;
    p_cpusubtype: cpu_subtype_t;
}

in4in6_addr :: struct {
    i46a_pad32: [3] u32;
    i46a_addr4: in_addr;
}

in_sockinfo :: struct {
    insi_fport:  s32; /* foreign port */
    insi_lport:  s32; /* local port */
    insi_gencnt: u64; /* generation count of this instance */
    insi_flags:  u32; /* generic IP/datagram flags */
    insi_flow:   u32;

    insi_vflag:  u8; /* ini_IPV4 or ini_IPV6 */
    insi_ip_ttl: u8; /* time to live proto */
    rfu_1:       u32; /* reserved */

    insi_faddr:  struct {
        ina_46: in4in6_addr;

        #overlay (ina_46) ina_6: in6_addr;
    }; /* foreign host table entry */

    insi_laddr:  struct {
        ina_46: in4in6_addr;

        #overlay (ina_46) ina_6: in6_addr;
    }; /* local host table entry */

    insi_v4:     struct {
        in4_tos: u8; /* type of service */
    };

    insi_v6:     struct {
        in6_hlim:    u8;
        in6_cksum:   s32;
        in6_ifindex: u16;
        in6_hops:    s16;
    };
}

tcp_sockinfo :: struct {
    tcpsi_ini:   in_sockinfo;
    tcpsi_state: s32;
    tcpsi_timer: [4] s32;
    tcpsi_mss:   s32;
    tcpsi_flags: u32;
    rfu_1:       u32; /* reserved */
    tcpsi_tp:    u64; /* opaque handle of TCP protocol control block */
}

/*
* Unix Domain Sockets
*/
un_sockinfo :: struct {
    unsi_conn_so:  u64; /* opaque handle of connected socket */
    unsi_conn_pcb: u64; /* opaque handle of connected protocol control block */
    unsi_addr:     struct {
        ua_dummy: [255] u8; // largest member, moved to the start of the struct/union to support #overlay.

        #overlay (ua_dummy) ua_sun: sockaddr_un;
    }; /* bound address */

    unsi_caddr:    struct {
        ua_dummy: [255] u8; // largest member, moved to the start of the struct/union to support #overlay.

        #overlay (ua_dummy) ua_sun: sockaddr_un;
    }; /* address of socket connected to */
}

/*
* PF_NDRV Sockets
*/
ndrv_info :: struct {
    ndrvsi_if_family: u32;
    ndrvsi_if_unit:   u32;
    ndrvsi_if_name:   [16] u8;
}

/*
* Kernel Event Sockets
*/
kern_event_info :: struct {
    kesi_vendor_code_filter: u32;
    kesi_class_filter:       u32;
    kesi_subclass_filter:    u32;
}

/*
* Kernel Control Sockets
*/
kern_ctl_info :: struct {
    kcsi_id:          u32;
    kcsi_reg_unit:    u32;
    kcsi_flags:       u32; /* support flags */
    kcsi_recvbufsize: u32; /* request more than the default buffer size */
    kcsi_sendbufsize: u32; /* request more than the default buffer size */
    kcsi_unit:        u32;
    kcsi_name:        [96] u8; /* unique nke identifier, provided by DTS */
}

/*
* VSock Sockets
*/
vsock_sockinfo :: struct {
    local_cid:   u32;
    local_port:  u32;
    remote_cid:  u32;
    remote_port: u32;
}

sockbuf_info :: struct {
    sbi_cc:    u32;
    sbi_hiwat: u32; /* SO_RCVBUF, SO_SNDBUF */
    sbi_mbcnt: u32;
    sbi_mbmax: u32;
    sbi_lowat: u32;
    sbi_flags: s16;
    sbi_timeo: s16;
}

SOCKINFO :: enum u32 {
    GENERIC    :: 0;
    IN         :: 1;
    TCP        :: 2;
    UN         :: 3;
    NDRV       :: 4;
    KERN_EVENT :: 5;
    KERN_CTL   :: 6;
    VSOCK      :: 7;

    SOCKINFO_GENERIC    :: GENERIC;
    SOCKINFO_IN         :: IN;
    SOCKINFO_TCP        :: TCP;
    SOCKINFO_UN         :: UN;
    SOCKINFO_NDRV       :: NDRV;
    SOCKINFO_KERN_EVENT :: KERN_EVENT;
    SOCKINFO_KERN_CTL   :: KERN_CTL;
    SOCKINFO_VSOCK      :: VSOCK;
}

socket_info :: struct {
    soi_stat:     vinfo_stat;
    soi_so:       u64; /* opaque handle of socket */
    soi_pcb:      u64; /* opaque handle of protocol control block */
    soi_type:     s32;
    soi_protocol: s32;
    soi_family:   s32;
    soi_options:  s16;
    soi_linger:   s16;
    soi_state:    s16;
    soi_qlen:     s16;
    soi_incqlen:  s16;
    soi_qlimit:   s16;
    soi_timeo:    s16;
    soi_error:    u16;
    soi_oobmark:  u32;
    soi_rcv:      sockbuf_info;
    soi_snd:      sockbuf_info;
    soi_kind:     s32;
    rfu_1:        u32; /* reserved */
    soi_proto:    struct {
        pri_un: un_sockinfo; // largest member, moved to the start of the struct/union to support #overlay. /* SOCKINFO_UN */

        #overlay (pri_un) pri_in:         in_sockinfo; /* SOCKINFO_IN */
        #overlay (pri_un) pri_tcp:        tcp_sockinfo; /* SOCKINFO_TCP */
        #overlay (pri_un) pri_ndrv:       ndrv_info; /* SOCKINFO_NDRV */
        #overlay (pri_un) pri_kern_event: kern_event_info; /* SOCKINFO_KERN_EVENT */
        #overlay (pri_un) pri_kern_ctl:   kern_ctl_info; /* SOCKINFO_KERN_CTL */
        #overlay (pri_un) pri_vsock:      vsock_sockinfo; /* SOCKINFO_VSOCK */
    };
}

socket_fdinfo :: struct {
    pfi: proc_fileinfo;
    psi: socket_info;
}

psem_info :: struct {
    psem_stat: vinfo_stat;
    psem_name: [1024] u8;
}

psem_fdinfo :: struct {
    pfi:      proc_fileinfo;
    pseminfo: psem_info;
}

pshm_info :: struct {
    pshm_stat:     vinfo_stat;
    pshm_mappaddr: u64;
    pshm_name:     [1024] u8;
}

pshm_fdinfo :: struct {
    pfi:      proc_fileinfo;
    pshminfo: pshm_info;
}

pipe_info :: struct {
    pipe_stat:       vinfo_stat;
    pipe_handle:     u64;
    pipe_peerhandle: u64;
    pipe_status:     s32;
    rfu_1:           s32; /* reserved */
}

pipe_fdinfo :: struct {
    pfi:      proc_fileinfo;
    pipeinfo: pipe_info;
}

kqueue_info :: struct {
    kq_stat:  vinfo_stat;
    kq_state: u32;
    rfu_1:    u32; /* reserved */
}

kqueue_dyninfo :: struct {
    kqdi_info:            kqueue_info;
    kqdi_servicer:        u64;
    kqdi_owner:           u64;
    kqdi_sync_waiters:    u32;
    kqdi_sync_waiter_qos: u8;
    kqdi_async_qos:       u8;
    kqdi_request_state:   u16;
    kqdi_events_qos:      u8;
    kqdi_pri:             u8;
    kqdi_pol:             u8;
    kqdi_cpupercent:      u8;
    _kqdi_reserved0:      [4] u8;
    _kqdi_reserved1:      [4] u64;
}

kqueue_fdinfo :: struct {
    pfi:        proc_fileinfo;
    kqueueinfo: kqueue_info;
}

appletalk_info :: struct {
    atalk_stat: vinfo_stat;
}

appletalk_fdinfo :: struct {
    pfi:           proc_fileinfo;
    appletalkinfo: appletalk_info;
}

proc_info_udata_t :: u64;

proc_fdinfo :: struct {
    proc_fd:     s32;
    proc_fdtype: u32;
}

proc_fileportinfo :: struct {
    proc_fileport: u32;
    proc_fdtype:   u32;
}

proc_channel_info :: struct {
    chi_instance: uuid_t;
    chi_port:     u32;
    chi_type:     u32;
    chi_flags:    u32;
    rfu_1:        u32; /* reserved */
}

channel_fdinfo :: struct {
    pfi:         proc_fileinfo;
    channelinfo: proc_channel_info;
}

audit_token_t :: struct {
    val: [8] u32;
}

/*!
*       @function proc_listpidspath
*       @discussion A function which will search through the current
*               processes looking for open file references which match
*               a specified path or volume.
*       @param type types of processes to be searched (see proc_listpids)
*       @param typeinfo adjunct information for type
*       @param path file or volume path
*       @param pathflags flags to control which files should be considered
*               during the process search.
*       @param buffer a C array of int-sized values to be filled with
*               process identifiers that hold an open file reference
*               matching the specified path or volume.  Pass NULL to
*               obtain the minimum buffer size needed to hold the
*               currently active processes.
*       @param buffersize the size (in bytes) of the provided buffer.
*       @result the number of bytes of data returned in the provided buffer;
*               -1 if an error was encountered;
*/
proc_listpidspath :: (type: u32, typeinfo: u32, path: *u8, pathflags: u32, buffer: *void, buffersize: s32) -> s32 #foreign libproc;

proc_listpids :: (type: u32, typeinfo: u32, buffer: *void, buffersize: s32) -> s32 #foreign libproc;
proc_listallpids :: (buffer: *void, buffersize: s32) -> s32 #foreign libproc;
proc_listpgrppids :: (pgrpid: pid_t, buffer: *void, buffersize: s32) -> s32 #foreign libproc;
proc_listchildpids :: (ppid: pid_t, buffer: *void, buffersize: s32) -> s32 #foreign libproc;
proc_pidinfo :: (pid: s32, flavor: s32, arg: u64, buffer: *void, buffersize: s32) -> s32 #foreign libproc;
proc_pidfdinfo :: (pid: s32, fd: s32, flavor: s32, buffer: *void, buffersize: s32) -> s32 #foreign libproc;
proc_pidfileportinfo :: (pid: s32, fileport: u32, flavor: s32, buffer: *void, buffersize: s32) -> s32 #foreign libproc;
proc_name :: (pid: s32, buffer: *void, buffersize: u32) -> s32 #foreign libproc;
proc_regionfilename :: (pid: s32, address: u64, buffer: *void, buffersize: u32) -> s32 #foreign libproc;
proc_kmsgbuf :: (buffer: *void, buffersize: u32) -> s32 #foreign libproc;
proc_pidpath :: (pid: s32, buffer: *void, buffersize: u32) -> s32 #foreign libproc;
proc_pidpath_audittoken :: (audittoken: *audit_token_t, buffer: *void, buffersize: u32) -> s32 #foreign libproc;
proc_libversion :: (major: *s32, minor: *s32) -> s32 #foreign libproc;

/*
* Return resource usage information for the given pid, which can be a live process or a zombie.
*
* Returns 0 on success; or -1 on failure, with errno set to indicate the specific error.
*/
proc_pid_rusage :: (pid: s32, flavor: s32, buffer: *rusage_info_t) -> s32 #foreign libproc;

proc_setpcontrol :: (control: s32) -> s32 #foreign libproc;

proc_track_dirty :: (pid: pid_t, flags: u32) -> s32 #foreign libproc;
proc_set_dirty :: (pid: pid_t, dirty: bool) -> s32 #foreign libproc;
proc_get_dirty :: (pid: pid_t, flags: *u32) -> s32 #foreign libproc;
proc_clear_dirty :: (pid: pid_t, flags: u32) -> s32 #foreign libproc;

proc_terminate :: (pid: pid_t, sig: *s32) -> s32 #foreign libproc;
proc_terminate_all_rsr :: (sig: s32) -> s32 #foreign libproc;
proc_signal_with_audittoken :: (audittoken: *audit_token_t, sig: s32) -> s32 #foreign libproc;
proc_terminate_with_audittoken :: (audittoken: *audit_token_t, sig: *s32) -> s32 #foreign libproc;
proc_signal_delegate :: (instigator: audit_token_t, target: audit_token_t, sig: s32) -> s32 #foreign libproc;
proc_terminate_delegate :: (instigator: audit_token_t, target: audit_token_t, sig: *s32) -> s32 #foreign libproc;

/*
* NO_SMT means that on an SMT CPU, this thread must be scheduled alone,
* with the paired CPU idle.
*
* Set NO_SMT on the current proc (all existing and future threads)
* This attribute is inherited on fork and exec
*/
proc_set_no_smt :: () -> s32 #foreign libproc;

/* Set NO_SMT on the current thread */
proc_setthread_no_smt :: () -> s32 #foreign libproc;

/*
* CPU Security Mitigation APIs
*
* Set CPU security mitigation on the current proc (all existing and future threads)
* This attribute is inherited on fork and exec
*/
proc_set_csm :: (flags: u32) -> s32 #foreign libproc;

/* Set CPU security mitigation on the current thread */
proc_setthread_csm :: (flags: u32) -> s32 #foreign libproc;

proc_udata_info :: (pid: s32, flavor: s32, buffer: *void, buffersize: s32) -> s32 #foreign libproc;

#scope_file

libproc :: #library,system "libproc";
