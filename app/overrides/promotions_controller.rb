Spree::Api::PromotionsController.class_eval do
  before_filter :requires_admin
  before_filter :load_promotion, except: :create

  def show
    if @promotion
      respond_with(@promotion, default_template: :show)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def create
    authorize! :create, Spree::Promotion

    @promotion = Spree::Promotion.create({
      name: params[:promotion][:name], # pass in name
      description: params[:promotion][:name], # pass in name as description
    match_policy: 'all'}) #default

    # pass in product ids
    @promotion.rules << Spree::Promotion::Rules::Product.create({preferred_match_policy: "any", products: Spree::Product.find(params[:promotion][:product_ids].split(","))})

    # pass in first_item and additional_item
    @promotion.actions << Spree::Promotion::Actions::CreateItemAdjustments.create({
      calculator: Spree::Calculator::FlexiRate.new( preferences: {:first_item=>params[:promotion][:first_item].to_d,
      :additional_item=>params[:promotion][:additional_item].to_d, :max_items=>0, :currency=>"USD"})
    })

    if @promotion.persisted?
      respond_with(@promotion, :status => 201, :default_template => :show)
    else
      invalid_resource!(@promotion)
    end
  end

  def update
    authorize! :update, @promotion

    if params[:promotion][:name]
      @promotion.update(
      name: params[:promotion][:name], # pass in name
      description: params[:promotion][:name]) # pass in name as description
    end

    if params[:promotion][:product_ids]
      # find promotion's product rule
      promo_rule = @promotion.rules.find_by(type: Spree::Promotion::Rules::Product)
      # pass in product ids
      if promo_rule
        promo_rule.update(products: Spree::Product.find(params[:promotion][:product_ids].split(",")))
      else
        @promotion.rules << Spree::Promotion::Rules::Product.create({preferred_match_policy: "any", products: Spree::Product.find(params[:promotion][:product_ids].split(","))})
      end
    end

    if params[:promotion][:first_item] || params[:promotion][:additional_item]
      # find promotion's action
      promo_action = @promotion.actions.find_by(type: Spree::Promotion::Actions::CreateItemAdjustments)
      # pass in converted first_item and additional_item values
      if promo_action
        promo_action.calculator.preferences[:first_item] = params[:promotion][:first_item].to_d if params[:promotion][:first_item]
        promo_action.calculator.preferences[:additional_item] = params[:promotion][:additional_item].to_d if params[:promotion][:additional_item]
        promo_action.calculator.save
      else
        @promotion.actions << Spree::Promotion::Actions::CreateItemAdjustments.create({
          calculator: Spree::Calculator::FlexiRate.new( preferences: {:first_item=>params[:promotion][:first_item].to_d,
          :additional_item=>params[:promotion][:additional_item].to_d, :max_items=>0, :currency=>"USD"})
        })
      end
    end

    if @promotion.errors.empty?
      respond_with(@promotion.reload, :status => 200, :default_template => :show)
    else
      invalid_resource!(@promotion)
    end
  end

  private
  def requires_admin
    return if @current_user_roles.include?("admin")
    unauthorized and return
  end

  def load_promotion
    @promotion = Spree::Promotion.find_by_id(params[:id]) || Spree::Promotion.with_coupon_code(params[:id])
  end
end
