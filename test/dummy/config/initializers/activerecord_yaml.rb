# See the following for details on why we need this for the deferred request library
# https://stackoverflow.com/questions/71191685/visit-psych-nodes-alias-unknown-alias-default-psychbadalias
# https://discuss.rubyonrails.org/t/cve-2022-32224-possible-rce-escalation-bug-with-serialized-columns-in-active-record/81017

if Gem::Version.new(Rails.version) >= Gem::Version.new("7.0.3.1")
  ActiveRecord.yaml_column_permitted_classes = [ActiveSupport::HashWithIndifferentAccess]
end
