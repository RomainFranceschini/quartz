module DEVS
  class NoSuchChildError < Exception; end
  class BadSynchronisationError < Exception; end
  class NoSuchPortError < Exception; end
  class InvalidPortHostError < Exception; end
  class InvalidPortModeError < Exception; end
  class MessageAlreadySentError < Exception; end
  class FeedbackLoopError < Exception; end
  class UnobservablePortError < Exception; end
end
