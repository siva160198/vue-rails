module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private
      def set_current_user
        session = Session.includes(:user).find_by(id: cookies.signed[:session_id])
        if session && !session.expired? && session.user.active?
          session.touch_activity!
          self.current_user = session.user
        else
          session&.destroy!
          nil
        end
      end
  end
end
