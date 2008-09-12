class TmAccountsController < ApplicationController
  def index
    @tm_accounts = TmAccount.find :all
  end
  
  def create
    @tm_account = TmAccount.create params[:tm_account]
    redirect_to :action => 'index'
  end
  
  def destroy
    TmAccount.find(params[:id]).destroy
    redirect_to :action => 'index'
  end
  
  def list_unfetched
    @tm_account = TmAccount.find(params[:id])
    @tickets = @tm_account.tickets.unfetched
    @unfetched = true
    render :action => 'list_tm_tickets'
  end
  
  def list_fetched
    @tm_account = TmAccount.find(params[:id])
    @tickets = @tm_account.tickets.fetched
    render :action => 'list_tm_tickets'
  end
end
