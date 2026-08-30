class EncryptExistingPhoneNumbers < ActiveRecord::Migration[8.1]
  def up
    User.where.not(phone: nil).find_each do |user|
      raw = user[:phone]
      user.update_column(:phone, SecurityEncryptor.encrypt(raw, purpose: "phone")) unless raw.start_with?(SecurityEncryptor::PREFIX)
    end
  end

  def down
    User.where("phone LIKE ?", "#{SecurityEncryptor::PREFIX}%").find_each do |user|
      user.update_column(:phone, SecurityEncryptor.decrypt(user[:phone], purpose: "phone"))
    end
  end
end
