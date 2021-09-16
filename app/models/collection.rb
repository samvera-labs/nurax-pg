# frozen_string_literal: true
# TODO: This is temporarily reverting Collection to an ActiveFedora::Base object
#       so the application will load.
class Collection < ActiveFedora::Base
  include ::Hyrax::CollectionBehavior
end
