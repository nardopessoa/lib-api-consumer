defmodule ApiConsumer.HTTP.LoggerBackend do
  require Logger
  @behaviour :gen_event

  @moduledoc """
  Modulo responsável por realizar log das requisições enviadas a API da TIM.
  Este modulo foi baseado no Backend já existente da lib `:logger_file_backend`,
  onde todos os callbacks necessários são redirecionados ao modulo LoggerFileBackend
  que possui a implementação para registrar os logs nos arquivos.

  Para que os textos sejam registrados em arquivos, basta informar a opção `:service`
  nos metadados das funções de log (Logger.debug/info/warn/error).

  Exemplo:
  Logger.info("Mensagem a ser feito log!", service: "Nome Do Serviço")

  Isto fará com que o arquivo `Nome do Serviço.log` seja criado no diretório
  informado na configuração path.
  """

  @doc false
  def init({_, name}) do
    LoggerFileBackend.init({LoggerFileBackend, name})
  end

  @doc false
  def code_change(old, state, extra) do
    LoggerFileBackend.code_change(old, state, extra)
  end

  @doc false
  def handle_call(params, state) do
    LoggerFileBackend.handle_call(params, state)
  end

  @doc false
  def handle_info(params, state) do
    LoggerFileBackend.handle_info(params, state)
  end

  @doc false
  def terminate(reason, state) do
    LoggerFileBackend.terminate(reason, state)
  end

  @doc false
  def handle_event(
        {level, _gl, {Logger, _, _, metadata}} = params,
        %{level: min_level, metadata_filter: _} = state
      ) do
    if log_in_file?(min_level, level, metadata) do
      service_name =
        metadata
        |> Keyword.get(:service)
        |> String.downcase()
        |> String.replace("\"", "")
        |> String.replace(" ", "_")

      state_with_path = Map.update!(state, :path, &(&1 <> service_name <> ".log"))

      case LoggerFileBackend.handle_event(params, state_with_path) do
        {:ok, new_state} ->
          path = Map.get(state, :path)
          new_state = Map.put(new_state, :path, path)
          {:ok, new_state}

        any ->
          any
      end
    else
      LoggerFileBackend.handle_event(:flush, state)
    end
  end

  def handle_event(params, state) do
    LoggerFileBackend.handle_event(params, state)
  end

  # o registro do log da mensagem só é realizado se:
  defp log_in_file?(min_level, level, metadata) do
    # o level está informado nas configurações
    # o level configurado é igual ou superior ao level da aplicação
    # se dentre os metadados possui a chave `:service`
    # se dentre os metadados possui a chave `:log?`
    # se dentre os metadados o valor dachave `:log?` é verdadeiro
    not is_nil(min_level) and Logger.compare_levels(level, min_level) !== :lt and
      not (metadata |> Keyword.get(:service) |> is_nil) and
      not (metadata |> Keyword.get(:log?) |> is_nil) and metadata |> Keyword.get(:log?)
  end

  @doc """
  Função responsável por realizar o log das requisições feitas aos serviços
  da API TIM. Para cada resposta, deve-se basear no nível de log configurado
  para o serviço em específico.
  """
  def log_service_response(log_level, true, service_name, request_verbose) do
    full_message = "#{service_name}\n#{request_verbose}"
    Logger.log(log_level, full_message)
  end

  def log_service_response(_log_level, _log?, _service_name, _request_verbose), do: :ok

  @doc """
  Função responsável por realizar o log das requisições feitas aos serviços
  da API TIM. Para erros identificados nas respostas, deve-se realizar o log
  como ERRO no arquivo específico do serviço.
  Caso haja exceção, a mesma não deve ser incluida no arquivo do serviço em
  questão, deve ser registrada no log geral do sistema (`backend: :console`)
  """
  def log_error(service_name, log?, request_verbose, step, exception) do
    service_message = function_log(step) <> (request_verbose || "") <> "\n"
    Logger.log(:error, service_message, service: service_name, log?: log?)
    full_message = service_message <> exception_log(exception) <> stacktrace_log(exception)
    Logger.log(:error, full_message)
    full_message
  end

  defp function_log(function_name) do
    "<< #{__MODULE__}.#{function_name} >> "
  end

  defp exception_log(nil), do: ""

  defp exception_log(exception) do
    "__ EXCEPTION: #{inspect(exception)}"
  end

  defp stacktrace_log(nil), do: ""

  defp stacktrace_log(exception) do
    if not Exception.exception?(exception),
      do: "",
      else: """
      __ STACKTRACE:
      #{Exception.format(:error, exception)}"
      """
  end

  @doc """
  Função que retorna a função na stacktrace baseado no index.
  Index 1: Process.info/2
  Index 2: __MODULE__.caller/1
  Do index 3 em diante são as funções executadas.
  """
  def caller(index \\ 3) do
    self()
    |> Process.info(:current_stacktrace)
    |> elem(1)
    |> Enum.at(index)
    |> Exception.format_stacktrace_entry()
  end

  @doc """
  Função utilizada para obter o modulo, função e aridade da linha em
  que é invocado.
  """
  defmacro current_function_name(sufix \\ "") do
    quote do
      mod = __ENV__.module
      {func_name, func_arity} = __ENV__.function
      "#{mod}.#{func_name}/#{func_arity}#{unquote(sufix)}"
    end
  end
end
