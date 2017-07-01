Sequel.migration do
  change do
    create_table :buildpack_lifecycle_buildpacks do
      VCAP::Migration.common(self, :buildpack_lifecycle_buildpacks)

      String :admin_buildpack_name
      String :encrypted_buildpack_url
      String :encrypted_buildpack_url_salt
      Integer :buildpack_lifecycle_data_id

      foreign_key [:buildpack_lifecycle_data_id], :buildpack_lifecycle_data, name: :fk_blbuildpack_bldata_id
      index [:buildpack_lifecycle_data_id], name: :bl_buildpack_bldata_id_index
    end
  end
end
