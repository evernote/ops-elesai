module Elesai; module Megacli

  class PDlist_aAll <  Megacli

    def initialize
      @megacli = { :adapter       => { :re => /^Adapter\s+#*(?<value>\d+)/,                         :method => self.method(:adapter_match) },
                   :physicaldrive => { :re => /^(?<key>Enclosure\s+Device\s+ID):\s+(?<value>\d+)/,  :method => self.method(:physicaldrive_match) },
                   :exit          => { :re => /^Exit Code: /,                                       :method => self.method(:exit_match) },
                   :attribute     => { :re => /^(?<key>[A-Za-z0-9()\s#'-.&]+)[:|=](?<value>.*)/,    :method => self.method(:attribute_match) }
      }.freeze
      @command_arguments = "-pdlist -aall".freeze
      @command_output_file = "pdlist_aall".freeze
    end

    def parse!(lsi,opts)
      fake = opts[:fake].nil? ? @command_arguments : File.join(opts[:fake],@command_output_file)
      super lsi, :fake => fake, :megacli => opts[:megacli]
    end

    # State Machine

    workflow do

      state :start do
        event :adapter_line, :transitions_to => :adapter
        event :exit_line, :transitions_to => :exit
      end

      state :adapter do
        event :adapter_line, :transitions_to => :adapter                 # empty adapter
        event :physicaldrive_line, :transitions_to => :physicaldrive
        event :exit_line, :transitions_to => :exit
      end

      state :physicaldrive do
        event :attribute_line, :transitions_to => :physicaldrive
        event :exit_line, :transitions_to => :exit
        event :adapter_line, :transitions_to => :adapter
        event :physicaldrive_line, :transitions_to => :physicaldrive
        event :attribute_line, :transitions_to => :attribute
      end

      state :attribute do
        event :attribute_line, :transitions_to => :attribute
        event :physicaldrive_line, :transitions_to => :physicaldrive
        event :adapter_line, :transitions_to => :adapter
        event :exit_line, :transitions_to => :exit
      end

      state :exit

      on_transition do |from, to, triggering_event, *event_args|
        #puts self.spec.states[to].class
        # puts "    transition: #{from} >> #{triggering_event}! >> #{to}: #{event_args.join(' ')}"
        #puts "                #{current_state.meta}"
      end
    end

    ### Match Handlers

    def virtualdrive_match(k,match)
      @log.debug "VIRTUALDRIVE! #{match.string}"
      key = match[:key].gsub(/\s+/,"").downcase
      value = match[:value]
      virtualdrive_line!(LSI::VirtualDrive.new,key,value)
    end

    def physicaldrive_match(k,match)
      @log.debug "PHYSICALDRIVE! #{match.string}"
      key = match[:key].gsub(/\s+/,"").downcase
      value = match[:value]
      physicaldrive_line!(LSI::PhysicalDrive.new,key,value)
    end

    ### Line Handlers

    #   Virtual Drives

    def virtualdrive_line(virtualdrive,key,value)
      @log.debug "  [#{current_state}] event: virtualdrive_line: new #{virtualdrive.inspect}"
      virtualdrive[key.to_sym] = value.to_i
    end

    def on_virtualdrive_entry(old_state, event, *args)
      @log.debug "        [#{current_state}] on_entry: leaving #{old_state}; args: #{args}"

      unless @context.current.nil?
        if Elesai::LSI::VirtualDrive === @context.current
          @context.close
        end
      end
      virtualdrive = args[0]
      @context.open virtualdrive
    end

    def on_virtualdrive_exit(new_state, event, *args)
      @log.debug "      [#{current_state}] on_exit: entering #{new_state}; args: #{args}"
      @context.flash!(new_state)
    end

    #   Physical Drives

    def physicaldrive_line(physicaldrive,key,value)
      @log.debug "  [#{current_state}] event: physicaldrive_line: new #{physicaldrive.inspect}"
      physicaldrive[key.to_sym] = value.to_i
    end

    def on_physicaldrive_entry(old_state, event, *args)
      @log.debug "        [#{current_state}] on_entry: leaving #{old_state}; args: #{args}"
      @context.open args[0]
    end

    def on_physicaldrive_exit(new_state, event, *args)
      @log.debug "      [#{current_state}] on_exit: entering #{new_state}; args: #{args}"
      @context.flash!(new_state)
    end

  end

end end