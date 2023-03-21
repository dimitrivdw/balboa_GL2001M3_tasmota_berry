class BalboaGL : Driver
    #serial variable
    var ser
    var heatingElementEnabled
    var buffer
    var currentTemperature
    var currentSetpoint

    def init()
        import gpio
        self.ser = serial(34,13,115200,serial.SERIAL_8N1)
        self.heatingElementEnabled = false
        self.buffer = []
        self.currentSetpoint = 5.0
        self.currentTemperature = 0.0
    end

    def enable_heating_element(cmd, idx, payload, payload_json)
        self.heatingElementEnabled = (payload == "YES")
        tasmota.resp_cmnd_done()
    end

    def every_50ms()
        if self.ser.available() > 0
            var read = self.ser.read();

            if read[0] == 0xFA && read[1] == 0x14
                var temp = 0
                if read[2] >= 49
                    temp += (read[2] - 48) * 10
                    temp += (read[3] - 48)
                    temp += (read[4] - 48) * 0.1
                    self.currentTemperature = temp;
                end
            end
            #self.buffer.push(read)
        end
    end

    def every_second()
        if (self.currentTemperature + 1) >= self.currentSetpoint && tasmota.get_power()[0] == true
            tasmota.set_power(0,false)
        end
        if (self.currentTemperature - 1) <= self.currentSetpoint && tasmota.get_power()[0] == false
            tasmota.set_power(0,true)
        end
    end

    #- display sensor value in the web UI -#
    def web_sensor()
        if !self.ser return nil end  #- exit if not initialized -#
        import string
        var msg = string.format(
                "{s}Temperature{m}%.1f °C{e}"..
                "{s}Setpoint{m}%.1f °C{e}"..
                "{s}Jets 1{m}%i{e}"..
                "{s}Jets 2{m}%i{e}"..
                "{s}Blower{m}%i{e}"..
                "{s}Heater requested{m}%i{e}"..
                "{s}Heating element possible{m}%i{e}"..
                "{s}Heating pump possible{m}%i{e}",
                self.currentTemperature, self.currentSetpoint, 0, 0, 0, 0,self.heatingElementEnabled,0)
        tasmota.web_send_decimal(msg)
    end

    #- add sensor value to teleperiod -#
    def json_append()
        if !self.ser return nil end  #- exit if not initialized -#
        import string
        
        var msg = string.format(",\"Balboa\":{\"Temperature\":%.1f,\"Setpoint\":%.1f,\"HeatingElementEnabled\":\"%s\"}",
                self.currentTemperature, self.currentSetpoint, self.heatingElementEnabled)
        tasmota.response_append(msg)
    end
end

balboa = BalboaGL()
tasmota.add_driver(balboa)

def enable_heating_element(cmd, idx, payload, payload_json)
    balboa.enable_heating_element(cmd, idx, payload, payload_json)
end

def set_setpoint(cmd,idx,payload,payload_json)
    balboa.currentSetpoint = real(payload)
    tasmota.resp_cmnd_done()
end

tasmota.add_cmd('EnableHeatingElement',enable_heating_element)
tasmota.add_cmd('Setpoint',set_setpoint)