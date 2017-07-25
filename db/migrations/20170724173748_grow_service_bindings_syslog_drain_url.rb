Sequel.migration do
  up do
    if self.class.name =~ /mysql/i
      alter_table :service_bindings do
        set_column_type :syslog_drain_url, String, text: true
      end
    end
  end
end
