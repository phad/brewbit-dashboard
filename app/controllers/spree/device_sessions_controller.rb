
module Spree
  class DeviceSessionsController < Spree::StoreController
    layout 'spree/layouts/devices'
    before_action :set_device
    before_action :set_device_session, only: [:show, :edit, :destroy]

    # GET /sessions
    def index
      @device_sessions = @device.sessions
    end

    # GET /sessions/1
    def show
    end

    # GET /sessions/new
    def new
      @device_session = Defaults.build_device_session @device
    end

    # GET /sessions/1/edit
    def edit
    end

    # POST /sessions
    def create
      begin
        DeviceSession.transaction do
          # create the new session, but don't save it yet because we need to
          # find and deactivate the old session first
          @device_session = DeviceSession.new(device_session_params)
          @device_session.active = true
          
          # deactivate old session
          old_session = @device.active_session_for @device_session.sensor_index
          if old_session
            old_session.active = false
            old_session.save!
          end
          
          # save the new session
          @device_session.save!

          DeviceService.send_session @device, @device_session
        end
      rescue
        puts $!.inspect, $@
        
        # build a new device_session including the outputs that were marked for destruction
        dsp = device_session_params
        dsp[:output_settings_attributes].each {|id, attrs| attrs.delete '_destroy' }
        @device_session = DeviceSession.new(dsp)
        
        flash[:notice] = 'Session could not be sent to the device.'
        render action: 'new'
      else
        redirect_to @device, notice: 'Device session was successfully sent.'
      end
    end

    # DELETE /sessions/1
    def destroy
      @device_session.destroy
      redirect_to device_sessions_url, notice: 'Device session was successfully destroyed.'
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_device_session
        @device_session = DeviceSession.find(params[:id])
      end

      def set_device
        @device = Device.find(params[:device_id])
      end

      # Only allow a trusted parameter "white list" through.
      def device_session_params
        params.require(:device_session).permit(
          :name, :device_id, :sensor_index, :setpoint_type, :static_setpoint, :temp_profile_id,
          output_settings_attributes: [:id, :output_index, :function, :cycle_delay, :sensor_id, :_destroy])
      end
  end
end
