class User < ApplicationRecord
  acts_as_paranoid
  if !Rails.env.test?
    searchkick
  end

  # Index name for a users is now:
  # classname_environment[if survey user has group, _groupmanagergroupname]
  # It has been overriden searchkick's class that sends data to elaticsearch, 
  # such that the index name is now defined by the model that is being 
  # evaluated using the function 'index_pattern_name'
  def index_pattern_name
    env = ENV['RAILS_ENV']
    if self.group.nil?
      return 'users_' + env
    end
    group_name = self.group.group_manager.group_name
    group_name.downcase!
    group_name.gsub! ' ', '-'
    return 'users_' + env + '_' + group_name
  end

  has_many :households,
    dependent: :destroy

  has_many :surveys,
    dependent: :destroy

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :jwt_authenticatable, jwt_revocation_strategy: JWTBlacklist

  belongs_to :app
  belongs_to :group, optional: true
  has_one :school_unit,
    dependent: :destroy
    
  validates :user_name,
    presence: true,
    length: {
      in: 1..255,
      too_long: I18n.translate("user.validations.user_name.too_long"),
      too_short: I18n.translate("user.validations.user_name.too_short")
    }

  validates :password,
    presence: true,
    length: {
      in: 8..255,
      too_long: I18n.translate("user.validations.password.too_long"),
      too_short: I18n.translate("user.validations.password.too_short")
    }

  validates :email,
    presence: true,
    length: {
      in: 1..255,
      message: "Email deve seguir o formato: example@example.com"
    },
    format: { with: URI::MailTo::EMAIL_REGEXP, message: I18n.translate("validations.email.message") },
    uniqueness: true

  # Data that gets sent as fields for elastic indexes
  def search_data
    elastic_data = self.as_json(except:['app_id', 'group_id', 'aux_code', 'reset_password_token'])
    elastic_data[:app] = self.app.app_name
    if !self.group.nil?
      elastic_data[:group] = self.group.get_path(string_only=true, labeled=false).join('/')
    else
      elastic_data[:group] = nil
    end
    if !self.school_unit_id.nil? and SchoolUnit.where(id:self.school_unit_id).count > 0
      elastic_data[:enrolled_in] = SchoolUnit.where(id:self.school_unit_id)[0].description 
    else 
      elastic_data[:enrolled_in] = nil 
    end
    elastic_data[:household_count] = self.households.count
    return elastic_data 
  end
end
