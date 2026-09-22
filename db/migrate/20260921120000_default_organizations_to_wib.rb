class DefaultOrganizationsToWib < ActiveRecord::Migration[8.1]
  def up
    change_column_default :organizations, :timezone, from: "UTC", to: "Jakarta"
    Organization.where(timezone: "UTC").update_all(timezone: "Jakarta")
  end

  def down
    change_column_default :organizations, :timezone, from: "Jakarta", to: "UTC"
  end
end
