import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario } from '../types'

type Props = {
  usuario: DadosUsuario
}

type RelacaoNome = {
  nome: string
}

type Demanda = {
  id: string
  empresa_id: string
  solicitante_id: string
  responsavel_id: string | null
  setor_id: string | null
  processo_id: string | null
  operacao_id: string | null
  execucao_id: string | null
  titulo: string
  descricao: string | null
  prioridade: string
  status: string
  data_prevista: string | null
  data_inicio: string | null
  data_conclusao: string | null
  percentual_conclusao: number
  created_at: string

  solicitante?: RelacaoNome | RelacaoNome[] | null
  responsavel?: RelacaoNome | RelacaoNome[] | null
  setor?: RelacaoNome | RelacaoNome[] | null
  processo?: RelacaoNome | RelacaoNome[] | null
  operacao?: RelacaoNome | RelacaoNome[] | null
}

type Pessoa = {
  id: string
  nome: string
  setor_id: string | null
}

type Setor = {
  id: string
  nome: string
}

type Processo = {
  id: string
  setor_id: string
  nome: string
}

type Operacao = {
  id: string
  setor_id: string
  processo_id: string
  nome: string
}

type Historico = {
  id: string
  status_anterior: string | null
  status_novo: string
  motivo: string | null
  created_at: string
  alterado_por_rel?: RelacaoNome | RelacaoNome[] | null
}

function normalizarRelacao<T>(
  valor: T | T[] | null | undefined
): T | null {
  if (!valor) return null

  if (Array.isArray(valor)) {
    return valor[0] || null
  }

  return valor
}

function formatarStatus(status: string) {
  return status.replaceAll('_', ' ')
}

function formatarData(data: string | null) {
  if (!data) return 'Sem prazo'

  return new Date(data).toLocaleString('pt-BR')
}

function atrasada(demanda: Demanda) {
  if (!demanda.data_prevista) return false

  if (
    demanda.status === 'CONCLUIDA' ||
    demanda.status === 'CANCELADA'
  ) {
    return false
  }

  return new Date(demanda.data_prevista) < new Date()
}

function DemandasPage({ usuario }: Props) {
  const [demandas, setDemandas] = useState<Demanda[]>([])
  const [pessoas, setPessoas] = useState<Pessoa[]>([])
  const [setores, setSetores] = useState<Setor[]>([])
  const [processos, setProcessos] = useState<Processo[]>([])
  const [operacoes, setOperacoes] = useState<Operacao[]>([])

  const [historico, setHistorico] = useState<Historico[]>([])

  const [demandaSelecionada, setDemandaSelecionada] =
    useState<Demanda | null>(null)

  const [carregando, setCarregando] = useState(true)
  const [salvando, setSalvando] = useState(false)
  const [mensagem, setMensagem] = useState('')

  const [mostrarFormulario, setMostrarFormulario] =
    useState(false)

  const [filtroStatus, setFiltroStatus] = useState('')
  const [filtroPrioridade, setFiltroPrioridade] =
    useState('')
  const [filtroResponsavel, setFiltroResponsavel] =
    useState('')
  const [filtroTexto, setFiltroTexto] = useState('')

  const [titulo, setTitulo] = useState('')
  const [descricao, setDescricao] = useState('')
  const [responsavelId, setResponsavelId] = useState('')
  const [setorId, setSetorId] = useState('')
  const [processoId, setProcessoId] = useState('')
  const [operacaoId, setOperacaoId] = useState('')
  const [prioridade, setPrioridade] = useState('NORMAL')
  const [dataPrevista, setDataPrevista] = useState('')

  async function carregarDados() {
    try {
      setCarregando(true)
      setMensagem('')

      const [
        demandasResposta,
        pessoasResposta,
        setoresResposta,
        processosResposta,
        operacoesResposta,
      ] = await Promise.all([
        supabase
          .from('demandas')
          .select(`
            id,
            empresa_id,
            solicitante_id,
            responsavel_id,
            setor_id,
            processo_id,
            operacao_id,
            execucao_id,
            titulo,
            descricao,
            prioridade,
            status,
            data_prevista,
            data_inicio,
            data_conclusao,
            percentual_conclusao,
            created_at,
            solicitante:pessoas!demandas_solicitante_id_fkey(nome),
            responsavel:pessoas!demandas_responsavel_id_fkey(nome),
            setor:setores(nome),
            processo:processos(nome),
            operacao:operacoes(nome)
          `)
          .eq('empresa_id', usuario.empresaId)
          .order('created_at', {
            ascending: false,
          }),

        supabase
          .from('pessoas')
          .select('id,nome,setor_id')
          .eq('empresa_id', usuario.empresaId)
          .eq('ativo', true)
          .order('nome'),

        supabase
          .from('setores')
          .select('id,nome')
          .eq('empresa_id', usuario.empresaId)
          .eq('ativo', true)
          .order('nome'),

        supabase
          .from('processos')
          .select('id,setor_id,nome')
          .eq('empresa_id', usuario.empresaId)
          .eq('ativo', true)
          .order('nome'),

        supabase
          .from('operacoes')
          .select('id,setor_id,processo_id,nome')
          .eq('empresa_id', usuario.empresaId)
          .eq('ativo', true)
          .order('nome'),
      ])

      if (demandasResposta.error) {
        throw demandasResposta.error
      }

      if (pessoasResposta.error) {
        throw pessoasResposta.error
      }

      if (setoresResposta.error) {
        throw setoresResposta.error
      }

      if (processosResposta.error) {
        throw processosResposta.error
      }

      if (operacoesResposta.error) {
        throw operacoesResposta.error
      }

      setDemandas(
        (demandasResposta.data || []) as Demanda[]
      )

      setPessoas(
        (pessoasResposta.data || []) as Pessoa[]
      )

      setSetores(
        (setoresResposta.data || []) as Setor[]
      )

      setProcessos(
        (processosResposta.data || []) as Processo[]
      )

      setOperacoes(
        (operacoesResposta.data || []) as Operacao[]
      )
    } catch (error) {
      console.error(error)

      setMensagem(
        'Erro ao carregar as demandas.'
      )
    } finally {
      setCarregando(false)
    }
  }

  async function carregarHistorico(demandaId: string) {
    try {
      const { data, error } = await supabase
        .from('demanda_status_historico')
        .select(`
          id,
          status_anterior,
          status_novo,
          motivo,
          created_at,
          alterado_por_rel:pessoas!demanda_status_historico_alterado_por_fkey(nome)
        `)
        .eq('demanda_id', demandaId)
        .order('created_at', {
          ascending: false,
        })

      if (error) throw error

      setHistorico(
        (data || []) as Historico[]
      )
    } catch (error) {
      console.error(error)
      setHistorico([])
    }
  }

  useEffect(() => {
    carregarDados()
  }, [usuario.empresaId])

  const processosFiltradosFormulario = useMemo(() => {
    if (!setorId) return processos

    return processos.filter(
      (item) => item.setor_id === setorId
    )
  }, [processos, setorId])

  const operacoesFiltradasFormulario = useMemo(() => {
    return operacoes.filter((item) => {
      if (
        setorId &&
        item.setor_id !== setorId
      ) {
        return false
      }

      if (
        processoId &&
        item.processo_id !== processoId
      ) {
        return false
      }

      return true
    })
  }, [operacoes, setorId, processoId])

  const demandasFiltradas = useMemo(() => {
    const texto = filtroTexto
      .trim()
      .toLocaleLowerCase()

    return demandas.filter((demanda) => {
      if (
        filtroStatus &&
        demanda.status !== filtroStatus
      ) {
        return false
      }

      if (
        filtroPrioridade &&
        demanda.prioridade !== filtroPrioridade
      ) {
        return false
      }

      if (
        filtroResponsavel &&
        demanda.responsavel_id !== filtroResponsavel
      ) {
        return false
      }

      if (texto) {
        const responsavel =
          normalizarRelacao(demanda.responsavel)?.nome ||
          ''

        const solicitante =
          normalizarRelacao(demanda.solicitante)?.nome ||
          ''

        const conteudo = [
          demanda.titulo,
          demanda.descricao || '',
          responsavel,
          solicitante,
        ]
          .join(' ')
          .toLocaleLowerCase()

        if (!conteudo.includes(texto)) {
          return false
        }
      }

      return true
    })
  }, [
    demandas,
    filtroStatus,
    filtroPrioridade,
    filtroResponsavel,
    filtroTexto,
  ])

  const resumo = useMemo(() => {
    const abertas = demandas.filter(
      (demanda) =>
        demanda.status !== 'CONCLUIDA' &&
        demanda.status !== 'CANCELADA'
    ).length

    const atrasadas = demandas.filter(atrasada).length

    const bloqueadas = demandas.filter(
      (demanda) =>
        demanda.status === 'BLOQUEADA'
    ).length

    const aguardando = demandas.filter(
      (demanda) =>
        demanda.status === 'AGUARDANDO'
    ).length

    return {
      abertas,
      atrasadas,
      bloqueadas,
      aguardando,
    }
  }, [demandas])

  function limparFormulario() {
    setTitulo('')
    setDescricao('')
    setResponsavelId('')
    setSetorId('')
    setProcessoId('')
    setOperacaoId('')
    setPrioridade('NORMAL')
    setDataPrevista('')
  }

  function fecharFormulario() {
    limparFormulario()
    setMostrarFormulario(false)
  }

  async function criarDemanda(
    e: React.FormEvent
  ) {
    e.preventDefault()

    if (!titulo.trim()) {
      setMensagem(
        'Informe o título da demanda.'
      )
      return
    }

    try {
      setSalvando(true)
      setMensagem('')

      const dataConvertida = dataPrevista
        ? new Date(dataPrevista).toISOString()
        : null

      const { data, error } = await supabase
        .from('demandas')
        .insert({
          empresa_id: usuario.empresaId,
          solicitante_id: usuario.pessoaId,
          responsavel_id:
            responsavelId || null,
          setor_id: setorId || null,
          processo_id: processoId || null,
          operacao_id: operacaoId || null,
          titulo: titulo.trim(),
          descricao:
            descricao.trim() || null,
          prioridade,
          status: 'ABERTA',
          data_prevista: dataConvertida,
          percentual_conclusao: 0,
        })
        .select('id')
        .single()

      if (error) throw error

      const { error: historicoError } =
        await supabase
          .from('demanda_status_historico')
          .insert({
            demanda_id: data.id,
            status_anterior: null,
            status_novo: 'ABERTA',
            alterado_por: usuario.pessoaId,
            motivo: 'Demanda criada',
          })

      if (historicoError) {
        throw historicoError
      }

      fecharFormulario()

      setMensagem(
        'Demanda criada com sucesso.'
      )

      await carregarDados()
    } catch (error) {
      console.error(error)

      setMensagem(
        'Erro ao criar a demanda.'
      )
    } finally {
      setSalvando(false)
    }
  }

  async function abrirDemanda(
    demanda: Demanda
  ) {
    setDemandaSelecionada(demanda)
    await carregarHistorico(demanda.id)
  }

  async function alterarStatus(
    demanda: Demanda,
    novoStatus: string,
    motivo?: string
  ) {
    if (demanda.status === novoStatus) {
      return
    }

    try {
      setSalvando(true)
      setMensagem('')

      const atualizacao: Record<
        string,
        string | number | null
      > = {
        status: novoStatus,
        updated_at: new Date().toISOString(),
      }

      if (
        novoStatus === 'EM_EXECUCAO' &&
        !demanda.data_inicio
      ) {
        atualizacao.data_inicio =
          new Date().toISOString()
      }

      if (novoStatus === 'CONCLUIDA') {
        atualizacao.data_conclusao =
          new Date().toISOString()

        atualizacao.percentual_conclusao = 100
      }

      if (novoStatus === 'CANCELADA') {
        atualizacao.data_conclusao =
          new Date().toISOString()
      }

      const { error } = await supabase
        .from('demandas')
        .update(atualizacao)
        .eq('id', demanda.id)

      if (error) throw error

      const { error: historicoError } =
        await supabase
          .from('demanda_status_historico')
          .insert({
            demanda_id: demanda.id,
            status_anterior: demanda.status,
            status_novo: novoStatus,
            alterado_por: usuario.pessoaId,
            motivo: motivo || null,
          })

      if (historicoError) {
        throw historicoError
      }

      await carregarDados()
      await carregarHistorico(demanda.id)

      setDemandaSelecionada((atual) =>
        atual
          ? {
              ...atual,
              status: novoStatus,
              percentual_conclusao:
                novoStatus === 'CONCLUIDA'
                  ? 100
                  : atual.percentual_conclusao,
            }
          : null
      )

      setMensagem(
        'Status atualizado com sucesso.'
      )
    } catch (error) {
      console.error(error)

      setMensagem(
        'Erro ao alterar o status.'
      )
    } finally {
      setSalvando(false)
    }
  }

  async function alterarProgresso(
    demanda: Demanda,
    percentual: number
  ) {
    const valor = Math.max(
      0,
      Math.min(100, percentual)
    )

    try {
      setSalvando(true)

      const { error } = await supabase
        .from('demandas')
        .update({
          percentual_conclusao: valor,
          updated_at: new Date().toISOString(),
        })
        .eq('id', demanda.id)

      if (error) throw error

      await carregarDados()

      setDemandaSelecionada((atual) =>
        atual
          ? {
              ...atual,
              percentual_conclusao: valor,
            }
          : null
      )
    } catch (error) {
      console.error(error)

      setMensagem(
        'Erro ao alterar o progresso.'
      )
    } finally {
      setSalvando(false)
    }
  }

  async function converterEmExecucao(
    demanda: Demanda
  ) {
    if (demanda.execucao_id) {
      setMensagem(
        'Esta demanda já possui uma execução vinculada.'
      )
      return
    }

    if (!demanda.operacao_id) {
      setMensagem(
        'Para transformar a demanda em execução, vincule uma operação à demanda.'
      )
      return
    }

    if (!demanda.responsavel_id) {
      setMensagem(
        'Defina um responsável antes de transformar a demanda em execução.'
      )
      return
    }

    const confirmar = window.confirm(
      'Transformar esta demanda em uma execução operacional?'
    )

    if (!confirmar) return

    try {
      setSalvando(true)
      setMensagem('')

      const { data: execucao, error } =
        await supabase
          .from('execucoes')
          .insert({
            operacao_id: demanda.operacao_id,
            responsavel_id:
              demanda.responsavel_id,
            titulo: demanda.titulo,
            descricao: demanda.descricao,
            status: 'NAO_INICIADA',
            prioridade: demanda.prioridade,
            data_prevista:
              demanda.data_prevista,
            percentual_conclusao: 0,
          })
          .select('id')
          .single()

      if (error) throw error

      const { error: participanteError } =
        await supabase
          .from('execucao_participantes')
          .insert({
            execucao_id: execucao.id,
            pessoa_id:
              demanda.responsavel_id,
            papel: 'RESPONSAVEL',
            ativo: true,
          })

      if (participanteError) {
        throw participanteError
      }

      const { error: execucaoHistoricoError } =
        await supabase
          .from('execucao_status_historico')
          .insert({
            execucao_id: execucao.id,
            status_anterior: null,
            status_novo: 'NAO_INICIADA',
            alterado_por: usuario.pessoaId,
            motivo: 'Execução criada a partir de demanda',
          })

      if (execucaoHistoricoError) {
        throw execucaoHistoricoError
      }

      const { error: demandaError } =
        await supabase
          .from('demandas')
          .update({
            execucao_id: execucao.id,
            status: 'EM_EXECUCAO',
            data_inicio:
              demanda.data_inicio ||
              new Date().toISOString(),
            updated_at:
              new Date().toISOString(),
          })
          .eq('id', demanda.id)

      if (demandaError) throw demandaError

      const { error: historicoError } =
        await supabase
          .from('demanda_status_historico')
          .insert({
            demanda_id: demanda.id,
            status_anterior: demanda.status,
            status_novo: 'EM_EXECUCAO',
            alterado_por: usuario.pessoaId,
            motivo:
              'Demanda transformada em execução operacional',
          })

      if (historicoError) {
        throw historicoError
      }

      setMensagem(
        'Demanda transformada em execução com sucesso.'
      )

      setDemandaSelecionada(null)
      setHistorico([])

      await carregarDados()
    } catch (error) {
      console.error(error)

      setMensagem(
        'Erro ao transformar a demanda em execução.'
      )
    } finally {
      setSalvando(false)
    }
  }

  async function cancelarDemanda(
    demanda: Demanda
  ) {
    const motivo = window.prompt(
      'Informe o motivo do cancelamento:'
    )

    if (motivo === null) return

    if (!motivo.trim()) {
      setMensagem(
        'O motivo do cancelamento é obrigatório.'
      )
      return
    }

    await alterarStatus(
      demanda,
      'CANCELADA',
      motivo.trim()
    )
  }

  async function concluirDemanda(
    demanda: Demanda
  ) {
    const confirmar = window.confirm(
      'Confirmar a conclusão desta demanda?'
    )

    if (!confirmar) return

    await alterarStatus(
      demanda,
      'CONCLUIDA',
      'Demanda concluída'
    )
  }

  if (carregando) {
    return (
      <>
        <header className="topbar">
          <div>
            <h1>Demandas</h1>
            <p>
              Solicitações e atividades não recorrentes
            </p>
          </div>

          <div className="topbar-user">
            {usuario.nome}
          </div>
        </header>

        <section className="panel">
          <div className="empty-state">
            Carregando demandas...
          </div>
        </section>
      </>
    )
  }

  return (
    <>
      <header className="topbar">
        <div>
          <h1>Demandas</h1>

          <p>
            Solicitações, responsabilidades e atividades
            não recorrentes
          </p>
        </div>

        <div className="topbar-user">
          {usuario.nome}
        </div>
      </header>

      {mensagem && (
        <div className="nexo-feedback">
          {mensagem}

          <button
            type="button"
            onClick={() => setMensagem('')}
          >
            ×
          </button>
        </div>
      )}

      <section className="cards-grid">
        <div className="status-card">
          <span className="card-label">
            Demandas abertas
          </span>

          <strong className="card-value">
            {resumo.abertas}
          </strong>
        </div>

        <div className="status-card">
          <span className="card-label">
            Atrasadas
          </span>

          <strong className="card-value">
            {resumo.atrasadas}
          </strong>
        </div>

        <div className="status-card">
          <span className="card-label">
            Bloqueadas
          </span>

          <strong className="card-value">
            {resumo.bloqueadas}
          </strong>
        </div>

        <div className="status-card">
          <span className="card-label">
            Aguardando
          </span>

          <strong className="card-value">
            {resumo.aguardando}
          </strong>
        </div>
      </section>

      <section className="panel">
        <div className="nexo-demandas-toolbar">
          <div>
            <h3>Controle de Demandas</h3>

            <p>
              Registre, distribua e acompanhe solicitações
              internas.
            </p>
          </div>

          <button
            className="nexo-primary-button"
            type="button"
            onClick={() =>
              setMostrarFormulario(true)
            }
          >
            + Nova demanda
          </button>
        </div>

        <div className="nexo-demandas-filtros">
          <input
            type="text"
            placeholder="Pesquisar demanda..."
            value={filtroTexto}
            onChange={(e) =>
              setFiltroTexto(e.target.value)
            }
          />

          <select
            value={filtroStatus}
            onChange={(e) =>
              setFiltroStatus(e.target.value)
            }
          >
            <option value="">
              Todos os status
            </option>

            <option value="ABERTA">
              Aberta
            </option>

            <option value="EM_ANALISE">
              Em análise
            </option>

            <option value="EM_EXECUCAO">
              Em execução
            </option>

            <option value="AGUARDANDO">
              Aguardando
            </option>

            <option value="BLOQUEADA">
              Bloqueada
            </option>

            <option value="CONCLUIDA">
              Concluída
            </option>

            <option value="CANCELADA">
              Cancelada
            </option>
          </select>

          <select
            value={filtroPrioridade}
            onChange={(e) =>
              setFiltroPrioridade(e.target.value)
            }
          >
            <option value="">
              Todas as prioridades
            </option>

            <option value="BAIXA">
              Baixa
            </option>

            <option value="NORMAL">
              Normal
            </option>

            <option value="ALTA">
              Alta
            </option>

            <option value="CRITICA">
              Crítica
            </option>
          </select>

          <select
            value={filtroResponsavel}
            onChange={(e) =>
              setFiltroResponsavel(e.target.value)
            }
          >
            <option value="">
              Todos os responsáveis
            </option>

            {pessoas.map((pessoa) => (
              <option
                key={pessoa.id}
                value={pessoa.id}
              >
                {pessoa.nome}
              </option>
            ))}
          </select>
        </div>

        {demandasFiltradas.length === 0 ? (
          <div className="empty-state">
            Nenhuma demanda encontrada.
          </div>
        ) : (
          <div className="table-wrapper">
            <table className="operations-table">
              <thead>
                <tr>
                  <th>Demanda</th>
                  <th>Solicitante</th>
                  <th>Responsável</th>
                  <th>Prioridade</th>
                  <th>Status</th>
                  <th>Prazo</th>
                  <th>Progresso</th>
                  <th></th>
                </tr>
              </thead>

              <tbody>
                {demandasFiltradas.map(
                  (demanda) => {
                    const solicitante =
                      normalizarRelacao(
                        demanda.solicitante
                      )

                    const responsavel =
                      normalizarRelacao(
                        demanda.responsavel
                      )

                    return (
                      <tr key={demanda.id}>
                        <td>
                          <strong>
                            {demanda.titulo}
                          </strong>

                          {atrasada(demanda) && (
                            <div className="nexo-danger-text">
                              ATRASADA
                            </div>
                          )}
                        </td>

                        <td>
                          {solicitante?.nome || '-'}
                        </td>

                        <td>
                          {responsavel?.nome ||
                            'Não definido'}
                        </td>

                        <td>
                          {demanda.prioridade}
                        </td>

                        <td>
                          {formatarStatus(
                            demanda.status
                          )}
                        </td>

                        <td>
                          {formatarData(
                            demanda.data_prevista
                          )}
                        </td>

                        <td>
                          {
                            demanda.percentual_conclusao
                          }
                          %
                        </td>

                        <td>
                          <button
                            className="nexo-link-button"
                            type="button"
                            onClick={() =>
                              abrirDemanda(
                                demanda
                              )
                            }
                          >
                            Abrir
                          </button>
                        </td>
                      </tr>
                    )
                  }
                )}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {mostrarFormulario && (
        <div className="nexo-modal-backdrop">
          <div className="nexo-modal">
            <div className="nexo-modal-header">
              <div>
                <h2>Nova demanda</h2>

                <p>
                  Registre uma nova solicitação.
                </p>
              </div>

              <button
                type="button"
                onClick={fecharFormulario}
              >
                ×
              </button>
            </div>

            <form
              className="nexo-demandas-form"
              onSubmit={criarDemanda}
            >
              <label>
                Título *
                <input
                  type="text"
                  value={titulo}
                  onChange={(e) =>
                    setTitulo(e.target.value)
                  }
                  required
                />
              </label>

              <label>
                Descrição
                <textarea
                  value={descricao}
                  onChange={(e) =>
                    setDescricao(e.target.value)
                  }
                  rows={4}
                />
              </label>

              <div className="nexo-form-grid">
                <label>
                  Responsável
                  <select
                    value={responsavelId}
                    onChange={(e) =>
                      setResponsavelId(
                        e.target.value
                      )
                    }
                  >
                    <option value="">
                      Não definido
                    </option>

                    {pessoas.map((pessoa) => (
                      <option
                        key={pessoa.id}
                        value={pessoa.id}
                      >
                        {pessoa.nome}
                      </option>
                    ))}
                  </select>
                </label>

                <label>
                  Prioridade
                  <select
                    value={prioridade}
                    onChange={(e) =>
                      setPrioridade(
                        e.target.value
                      )
                    }
                  >
                    <option value="BAIXA">
                      Baixa
                    </option>

                    <option value="NORMAL">
                      Normal
                    </option>

                    <option value="ALTA">
                      Alta
                    </option>

                    <option value="CRITICA">
                      Crítica
                    </option>
                  </select>
                </label>

                <label>
                  Setor
                  <select
                    value={setorId}
                    onChange={(e) => {
                      setSetorId(
                        e.target.value
                      )

                      setProcessoId('')
                      setOperacaoId('')
                    }}
                  >
                    <option value="">
                      Sem vínculo
                    </option>

                    {setores.map((setor) => (
                      <option
                        key={setor.id}
                        value={setor.id}
                      >
                        {setor.nome}
                      </option>
                    ))}
                  </select>
                </label>

                <label>
                  Processo
                  <select
                    value={processoId}
                    onChange={(e) => {
                      setProcessoId(
                        e.target.value
                      )

                      setOperacaoId('')
                    }}
                  >
                    <option value="">
                      Sem vínculo
                    </option>

                    {processosFiltradosFormulario.map(
                      (processo) => (
                        <option
                          key={processo.id}
                          value={processo.id}
                        >
                          {processo.nome}
                        </option>
                      )
                    )}
                  </select>
                </label>

                <label>
                  Operação
                  <select
                    value={operacaoId}
                    onChange={(e) =>
                      setOperacaoId(
                        e.target.value
                      )
                    }
                  >
                    <option value="">
                      Sem vínculo
                    </option>

                    {operacoesFiltradasFormulario.map(
                      (operacao) => (
                        <option
                          key={operacao.id}
                          value={operacao.id}
                        >
                          {operacao.nome}
                        </option>
                      )
                    )}
                  </select>
                </label>

                <label>
                  Prazo
                  <input
                    type="datetime-local"
                    value={dataPrevista}
                    onChange={(e) =>
                      setDataPrevista(
                        e.target.value
                      )
                    }
                  />
                </label>
              </div>

              <div className="nexo-modal-actions">
                <button
                  type="button"
                  className="nexo-secondary-button"
                  onClick={fecharFormulario}
                >
                  Cancelar
                </button>

                <button
                  type="submit"
                  className="nexo-primary-button"
                  disabled={salvando}
                >
                  {salvando
                    ? 'Salvando...'
                    : 'Criar demanda'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {demandaSelecionada && (
        <div className="nexo-modal-backdrop">
          <div className="nexo-modal nexo-modal-large">
            <div className="nexo-modal-header">
              <div>
                <h2>
                  {demandaSelecionada.titulo}
                </h2>

                <p>
                  Gestão e acompanhamento da demanda
                </p>
              </div>

              <button
                type="button"
                onClick={() => {
                  setDemandaSelecionada(null)
                  setHistorico([])
                }}
              >
                ×
              </button>
            </div>

            <div className="nexo-demanda-detalhes">
              <div className="nexo-execution-summary">
                <div>
                  <span>Status</span>

                  <strong>
                    {formatarStatus(
                      demandaSelecionada.status
                    )}
                  </strong>
                </div>

                <div>
                  <span>Prioridade</span>

                  <strong>
                    {
                      demandaSelecionada.prioridade
                    }
                  </strong>
                </div>

                <div>
                  <span>Prazo</span>

                  <strong>
                    {formatarData(
                      demandaSelecionada.data_prevista
                    )}
                  </strong>
                </div>

                <div>
                  <span>Progresso</span>

                  <strong>
                    {
                      demandaSelecionada.percentual_conclusao
                    }
                    %
                  </strong>
                </div>
              </div>

              {demandaSelecionada.descricao && (
                <div className="nexo-demanda-descricao">
                  <strong>Descrição</strong>

                  <p>
                    {
                      demandaSelecionada.descricao
                    }
                  </p>
                </div>
              )}

              <div className="nexo-form-grid">
                <label>
                  Status
                  <select
                    value={
                      demandaSelecionada.status
                    }
                    disabled={salvando}
                    onChange={(e) =>
                      alterarStatus(
                        demandaSelecionada,
                        e.target.value
                      )
                    }
                  >
                    <option value="ABERTA">
                      Aberta
                    </option>

                    <option value="EM_ANALISE">
                      Em análise
                    </option>

                    <option value="EM_EXECUCAO">
                      Em execução
                    </option>

                    <option value="AGUARDANDO">
                      Aguardando
                    </option>

                    <option value="BLOQUEADA">
                      Bloqueada
                    </option>

                    <option value="CONCLUIDA">
                      Concluída
                    </option>

                    <option value="CANCELADA">
                      Cancelada
                    </option>
                  </select>
                </label>

                <label>
                  Progresso
                  <input
                    type="number"
                    min="0"
                    max="100"
                    value={
                      demandaSelecionada.percentual_conclusao
                    }
                    disabled={salvando}
                    onChange={(e) =>
                      alterarProgresso(
                        demandaSelecionada,
                        Number(e.target.value)
                      )
                    }
                  />
                </label>
              </div>

              <hr className="nexo-divider" />

              <div className="nexo-demanda-vinculos">
                <h3>Vínculos</h3>

                <div className="nexo-execution-summary">
                  <div>
                    <span>Solicitante</span>

                    <strong>
                      {normalizarRelacao(
                        demandaSelecionada.solicitante
                      )?.nome || '-'}
                    </strong>
                  </div>

                  <div>
                    <span>Responsável</span>

                    <strong>
                      {normalizarRelacao(
                        demandaSelecionada.responsavel
                      )?.nome || 'Não definido'}
                    </strong>
                  </div>

                  <div>
                    <span>Setor</span>

                    <strong>
                      {normalizarRelacao(
                        demandaSelecionada.setor
                      )?.nome || '-'}
                    </strong>
                  </div>

                  <div>
                    <span>Processo</span>

                    <strong>
                      {normalizarRelacao(
                        demandaSelecionada.processo
                      )?.nome || '-'}
                    </strong>
                  </div>

                  <div>
                    <span>Operação</span>

                    <strong>
                      {normalizarRelacao(
                        demandaSelecionada.operacao
                      )?.nome || '-'}
                    </strong>
                  </div>

                  <div>
                    <span>Execução</span>

                    <strong>
                      {demandaSelecionada.execucao_id
                        ? 'Vinculada'
                        : 'Não criada'}
                    </strong>
                  </div>
                </div>
              </div>

              <hr className="nexo-divider" />

              <div>
                <h3>Histórico</h3>

                {historico.length === 0 ? (
                  <div className="empty-state">
                    Nenhuma alteração registrada.
                  </div>
                ) : (
                  <div className="nexo-record-list">
                    {historico.map((item) => {
                      const pessoa =
                        normalizarRelacao(
                          item.alterado_por_rel
                        )

                      return (
                        <div
                          className="nexo-record"
                          key={item.id}
                        >
                          <div>
                            <strong>
                              {item.status_anterior
                                ? `${formatarStatus(
                                    item.status_anterior
                                  )} → ${formatarStatus(
                                    item.status_novo
                                  )}`
                                : formatarStatus(
                                    item.status_novo
                                  )}
                            </strong>

                            <p>
                              {item.motivo ||
                                'Sem observação'}
                            </p>
                          </div>

                          <div>
                            <small>
                              {pessoa?.nome || '-'}
                            </small>

                            <p>
                              {new Date(
                                item.created_at
                              ).toLocaleString(
                                'pt-BR'
                              )}
                            </p>
                          </div>
                        </div>
                      )
                    })}
                  </div>
                )}
              </div>

              <div className="nexo-demanda-acoes">
                {!demandaSelecionada.execucao_id &&
                  demandaSelecionada.status !==
                    'CONCLUIDA' &&
                  demandaSelecionada.status !==
                    'CANCELADA' && (
                    <button
                      type="button"
                      className="nexo-primary-button"
                      disabled={salvando}
                      onClick={() =>
                        converterEmExecucao(
                          demandaSelecionada
                        )
                      }
                    >
                      Transformar em execução
                    </button>
                  )}

                {demandaSelecionada.status !==
                  'CONCLUIDA' &&
                  demandaSelecionada.status !==
                    'CANCELADA' && (
                    <>
                      <button
                        type="button"
                        className="nexo-secondary-button"
                        disabled={salvando}
                        onClick={() =>
                          concluirDemanda(
                            demandaSelecionada
                          )
                        }
                      >
                        Concluir demanda
                      </button>

                      <button
                        type="button"
                        className="nexo-danger-button"
                        disabled={salvando}
                        onClick={() =>
                          cancelarDemanda(
                            demandaSelecionada
                          )
                        }
                      >
                        Cancelar demanda
                      </button>
                    </>
                  )}
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  )
}

export default DemandasPage