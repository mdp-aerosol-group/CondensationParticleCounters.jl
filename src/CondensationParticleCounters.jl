module CondensationParticleCounters

using LibSerialPort
using Dates
using DataStructures
using Chain

const dataBuffer = CircularBuffer{String}(10)

function get_config(CPCType)
    if (CPCType == :TSI3022) || (CPCType == :TSI3025)
        q = 0.3
        baud = 9600
        dbits = 7
        parity = SP_PARITY_EVEN
        sbits = 1
    elseif (CPCType == :TSI3771) || (CPCType == :TSI3772) || (CPCType == :TSI3776C)
        q = 1.0
        baud = 115200
        dbits = 8
        parity = SP_PARITY_NONE
        sbits = 1
    elseif (CPCType == :DMTCCN)
        q = 0.5
        baud = 9600
        dbits = 8
        parity = SP_PARITY_NONE
        sbits = 1
     elseif (CPCType == :MAGIC)
        q = 0.3
        baud = 115200
        dbits = 8
        parity = SP_PARITY_NONE
        sbits = 1
    end

    return (q = q, baud = baud, dbits = dbits, parity = parity, sbits = sbits)
end

function config(CPCType::Symbol, portname::String)
    conf = get_config(CPCType)

    port = LibSerialPort.sp_get_port_by_name(portname)
    LibSerialPort.sp_open(port, SP_MODE_READ_WRITE)
    config = LibSerialPort.sp_get_config(port)
    LibSerialPort.sp_set_config_baudrate(config, conf.baud)
    LibSerialPort.sp_set_config_parity(config, conf.parity)
    LibSerialPort.sp_set_config_bits(config, conf.dbits)
    LibSerialPort.sp_set_config_stopbits(config, conf.sbits)
    LibSerialPort.sp_set_config_rts(config, SP_RTS_OFF)
    LibSerialPort.sp_set_config_cts(config, SP_CTS_IGNORE)
    LibSerialPort.sp_set_config_dtr(config, SP_DTR_OFF)
    LibSerialPort.sp_set_config_dsr(config, SP_DSR_IGNORE)

    LibSerialPort.sp_set_config(port, config)

    return port
end

function stream(port::Ptr{LibSerialPort.Lib.SPPort}, CPCType::Symbol, file::String)
    Godot = @task _ -> false

    function read(port, file)
        try
            tc = Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")
            if (CPCType == :TSI3771) || (CPCType == :TSI3772) || (CPCType == :TSI3776C)
                LibSerialPort.sp_nonblocking_write(port, "RALL\r")
                nbytes_read, bytes = LibSerialPort.sp_nonblocking_read(port, 100)
            elseif  (CPCType == :TSI3022) || (CPCType == :TSI3025) 
                LibSerialPort.sp_nonblocking_write(port, "RD\r")
                nbytes_read, bytes = LibSerialPort.sp_nonblocking_read(port, 100)
            elseif (CPCType == :MAGIC)
                 nbytes_read, bytes = LibSerialPort.sp_nonblocking_read(port, 1000)
            end
            str = String(bytes[1:nbytes_read])
            tc = Dates.format(now(), "yyyymmdd")
            open(file*"_"*tc*".txt", "a") do io
                write(io, tc * "," * str)
            end
            push!(dataBuffer, "RALL," * tc * "," * str)
        catch
            println("From CondensationParticleCounters.jl: I fail")
        end
    end

    while(true)
        read(port, file)
        sleep(1)
    end

    wait(Godot)
end

function get_current_record()
    try 
        x = dataBuffer[end]
        ifelse((x[end] == '\r'), x, missing) 
    catch
        missing
    end
end

end 
