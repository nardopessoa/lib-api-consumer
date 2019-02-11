defmodule ApiConsumer.HTTP.ConfigHelper do
  @moduledoc """
  Módulo responsável por obter dos arquivos de configuração todas as
  informações necessárias para execução das requisições
  """

  def log?(module, opts \\ []) do
    config_service(module, :log?, opts) || true
  end

  def log_level(module, opts \\ []) do
    config_service(module, :log_level, opts) || Logger.level()
  end

  def page_size(module, opts \\ []) do
    config_service(module, :page_size, opts) || 10
  end

  def attempts_amount(module, opts \\ []) do
    config_service(module, :attempts_amount, opts) || 3
  end

  def sleep_seconds_between_attempts(module, opts \\ []) do
    seconds = config_service(module, :sleep_seconds_between_attempts, opts) || 2

    :timer.seconds(seconds)
  end

  ###############################
  ######### PRIVATE #############
  ###############################

  defp config_service(module, key, opts) do
    app_name = application_name(module)

    Keyword.get(opts || [], key) || config_value(app_name, module, key) ||
      config_value(app_name, :service, key)
  end

  defp config_value(app_name, module), do: Application.get_env(app_name, module)

  defp config_value(app_name, module, key) do
    (config_value(app_name, module) || [])[key]
  end

  defp application_name(module) do
    module |> :application.get_application() |> extract_name || module
  end

  defp extract_name({:ok, app_name}), do: app_name
  defp extract_name(_), do: nil
end
