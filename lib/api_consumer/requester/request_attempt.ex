defmodule ApiConsumer.Requester.RequestAttempt do
  alias ApiConsumer.Requester

  @moduledoc """
  Entidade responsável por registrar e manter os dados estatísticos
  das requisições realizadas aos serviços de uma API.

  :account - referencia utilizada para obter os dados de login
    (customer_id e msisdn)
  :request_errors - referencia onde se registra os erros ocorridos
    entre as tentativas

  :service - identificador do serviço. Preferencia por possuir os
    mesmos nomes da documentação da TIM, para facilitar manutenção
  :attempt - tentativa ao qual a requisição foi executado.
  :success_quantity - quantidade de requisições executadas com
    SUCESSO nesta tentativa
  :error_quantity - quantidade de requisições executadas com ERRO
    nesta tentativa

  :result - campo utilizado em tempo de execução para armazenar a
    resposta da requisição
  """

  defstruct account: nil,

            # %Requester.Account{}
            # %Requester.RequestError{}
            request_errors: nil,
            # :string
            service: nil,
            # :string
            attempt: nil,
            # :integer
            success_quantity: nil,
            # :integer
            error_quantity: nil,
            # :map
            result: nil,
            created_at: Timex.now(),
            updated_at: Timex.now()

  def find_or_create_request_attempt(_struct, _attempt)
  def find_or_create_request_attempt(_struct, nil), do: %__MODULE__{}

  def find_or_create_request_attempt(_struct, %Requester.RequestError{} = attempt) do
    # TODO buscar na base de dados um registro existente ou criar um novo
    attempt.request_attempt
  end

  def request_attempt_with_result(%Requester.RequestError{} = request_error, result) do
    attempt =
      request_error
      |> Map.put(:exception, result)
      |> Map.get(:request_attempt)
      |> request_attempt_with_result(result)

    Map.put(request_error, :request_attempt, attempt)
  end

  def request_attempt_with_result(%__MODULE__{} = request_attempt, result) do
    Map.put(request_attempt, :result, result)
  end

  def check_attempt(struct, attempt) do
    if attempt <= struct.opts[:retry],
      do: attempt + 1,
      else: :stop
  end
end
