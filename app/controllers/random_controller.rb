class RandomController < ApplicationController
  include Facts
  def fact
    binding.pry
  end
end
