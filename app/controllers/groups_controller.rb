# frozen_string_literal: true

class GroupsController < ApplicationController
  before_action :authenticate_user!, only: %i[create join leave]
  before_action :set_group, only: %i[show join leave]

  def index
    @groups = Group.includes(:group_memberships).order(:name)
    @group = Group.new
  end

  def show
    @members = @group.members.order(:username).limit(24)
    @membership = current_user&.group_memberships&.find_by(group: @group)
  end

  def create
    @group = Group.new(group_params)
    if @group.save
      @group.group_memberships.create!(user: current_user, role: "owner")
      redirect_to group_path(@group), notice: t("groups.created")
    else
      @groups = Group.includes(:group_memberships).order(:name)
      flash.now[:alert] = @group.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def join
    @group.group_memberships.find_or_create_by!(user: current_user) do |m|
      m.role = "member"
    end
    redirect_to group_path(@group), notice: t("groups.joined")
  end

  def leave
    membership = @group.group_memberships.find_by(user: current_user)
    if membership&.role == "owner" && @group.group_memberships.where(role: "owner").count == 1
      redirect_to group_path(@group), alert: t("groups.owner_cannot_leave")
      return
    end

    membership&.destroy
    redirect_to groups_path, notice: t("groups.left")
  end

  private

  def set_group
    @group = Group.find_by!(slug: params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to groups_path, alert: t("groups.not_found")
  end

  def group_params
    params.require(:group).permit(:name, :description)
  end
end
