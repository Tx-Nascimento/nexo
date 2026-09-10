import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario } from '../types'

type Props = {
  usuario: DadosUsuario
}

type Operacao = {
  id: string
  nome: string
  prioridade: string
  tempo_estimado_minutos: number | null
  exige_conferencia: boolean
  exige_aprovacao: boolean
  exige_evidencia: boolean
}

type Pessoa = {
  id: string
  nome: string
  ativo: boolean
}

type Execucao = {
  id: string
  operacao_id: string
  responsavel_id: string | null
  titulo: string
  descricao: string | null
  status: string
  prioridade: string
  data_prevista: string | null
  data_inicio: string | null
  data_conclusao: string | null
  percentual_conclusao: number
  operacao?: {
    nome: string
  } | null
  responsavel?: {
    nome: string
  } | null
}

type Dependencia = {
  id: string
  tipo_dependencia: string
  motivo: string
  descricao: string | null
  impacto: string
  previsao_retorno: string | null
  proxima_acao: string | null
  ativo: boolean
  iniciado_em: string
  finalizado_em: string | null
}

type Bloqueio = {
  id: string
  motivo: string
  descricao: string | null
  iniciado_em: string
  finalizado_em: string | null
  resolucao: string | null
  ativo: boolean
}

type Conferencia = {
  id: string
  conferente_id: string
  resultado: string
  observacao: string | null
  iniciado_em: string
  finalizado_em: string | null
  conferente?: {
    nome: string
  } | null
}

type Aprovacao = {
  id: string
  aprovador_id: string
  status: string
  observacao: string | null
  solicitado_em: string
  respondido_em: string | null
  aprovador?: {
    nome: string
  } | null
}

type Retrabalho = {
  id: string
  categoria: string
  motivo: string
  descricao: string | null
  status: string
  numero_retorno: number
  iniciado_em: string
  corrigido_em: string | null
  responsavel_correcao?: {
    nome: string
  } | null
}

const STATUS = [
  'NAO_INICIADA',
  'EM_EXECUCAO',
  'AGUARDANDO_INFORMACAO',
  'AGUARDANDO_TERCEIRO',
  'AGUARDANDO_CONFERENCIA',
  'AGUARDANDO_APROVACAO',
  'BLOQUEADA',
  'CONCLUIDA',
  'CANCELADA',
]

function normalizarRelacao<T>(valor: T | T[] | null | undefined): T | null {
  if (!valor) return null
  return Array.isArray(valor) ? valor[0] || null : valor
}

function formatarStatus(status: string) {
  return status.replaceAll('_', ' ')
}

function formatarData(data: string | null) {
  if (!data) return '—'

  return new Date(data).toLocaleString('pt-BR')
}

function estaAtrasada(execucao: Execucao) {
  if (!execucao.data_prevista) return false
  if (['CONCLUIDA', 'CANCELADA'].includes(execucao.status)) return false

  return new Date(execucao.data_prevista).getTime() < Date.now()
}

export default function OperacoesPage({ usuario }: Props) {
  const [execucoes, setExecucoes] = useState<Execucao[]>([])
  const [operacoes, setOperacoes] = useState<Operacao[]>([])
  const [pessoas, setPessoas] = useState<Pessoa[]>([])

  const [selecionada, setSelecionada] = useState<Execucao | null>(null)

  const [dependencias, setDependencias] = useState<Dependencia[]>([])
  const [bloqueios, setBloqueios] = useState<Bloqueio[]>([])
  const [conferencias, setConferencias] = useState<Conferencia[]>([])
  const [aprovacoes, setAprovacoes] = useState<Aprovacao[]>([])
  const [retrabalhos, setRetrabalhos] = useState<Retrabalho[]>([])

  const [mostrarNova, setMostrarNova] = useState(false)
  const [mensagem, setMensagem] = useState('')
  const [carregando, setCarregando] = useState(false)

  const [novaOperacaoId, setNovaOperacaoId] = useState('')
  const [novoResponsavelId, setNovoResponsavelId] = useState('')
  const [novoTitulo, setNovoTitulo] = useState('')
  const [novaDescricao, setNovaDescricao] = useState('')
  const [novaDataPrevista, setNovaDataPrevista] = useState('')
  const [novaPrioridade, setNovaPrioridade] = useState('NORMAL')

  const [dependenciaTipo, setDependenciaTipo] = useState('INFORMACAO')
  const [dependenciaMotivo, setDependenciaMotivo] = useState('')
  const [dependenciaDescricao, setDependenciaDescricao] = useState('')
  const [dependenciaImpacto, setDependenciaImpacto] = useState('MEDIO')
  const [dependenciaPrevisao, setDependenciaPrevisao] = useState('')
  const [dependenciaProximaAcao, setDependenciaProximaAcao] = useState('')

  const [bloqueioMotivo, setBloqueioMotivo] = useState('')
  const [bloqueioDescricao, setBloqueioDescricao] = useState('')

  const [conferenteId, setConferenteId] = useState('')
  const [aprovadorId, setAprovadorId] = useState('')

  const [retrabalhoResponsavelId, setRetrabalhoResponsavelId] = useState('')
  const [retrabalhoCategoria, setRetrabalhoCategoria] =
    useState('ERRO_EXECUCAO')
  const [retrabalhoMotivo, setRetrabalhoMotivo] = useState('')
  const [retrabalhoDescricao, setRetrabalhoDescricao] = useState('')

  async function carregarBase() {
    try {
      setCarregando(true)
      setMensagem('')

      const [execResponse, opResponse, pessoasResponse] = await Promise.all([
        supabase
          .from('execucoes')
          .select(`
            id,
            operacao_id,
            responsavel_id,
            titulo,
            descricao,
            status,
            prioridade,
            data_prevista,
            data_inicio,
            data_conclusao,
            percentual_conclusao,
            operacao:operacoes!inner(
              nome,
              empresa_id
            ),
            responsavel:pessoas(
              nome
            )
          `)
          .eq('operacao.empresa_id', usuario.empresaId)
          .order('data_prevista', { ascending: true }),

        supabase
          .from('operacoes')
          .select(`
            id,
            nome,
            prioridade,
            tempo_estimado_minutos,
            exige_conferencia,
            exige_aprovacao,
            exige_evidencia
          `)
          .eq('empresa_id', usuario.empresaId)
          .eq('ativo', true)
          .order('nome'),

        supabase
          .from('pessoas')
          .select('id,nome,ativo')
          .eq('empresa_id', usuario.empresaId)
          .eq('ativo', true)
          .order('nome'),
      ])

      if (execResponse.error) throw execResponse.error
      if (opResponse.error) throw opResponse.error
      if (pessoasResponse.error) throw pessoasResponse.error

      const execucoesNormalizadas = (execResponse.data || []).map(
        (item: any) => ({
          ...item,
          operacao: normalizarRelacao(item.operacao),
          responsavel: normalizarRelacao(item.responsavel),
        })
      )

      setExecucoes(execucoesNormalizadas as Execucao[])
      setOperacoes((opResponse.data || []) as Operacao[])
      setPessoas((pessoasResponse.data || []) as Pessoa[])

      if (selecionada) {
        const atualizada = execucoesNormalizadas.find(
          (x) => x.id === selecionada.id
        )

        if (atualizada) {
          setSelecionada(atualizada as Execucao)
        }
      }
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao carregar operações.')
    } finally {
      setCarregando(false)
    }
  }

  async function carregarDetalhes(execucaoId: string) {
    try {
      const [
        dependenciasResponse,
        bloqueiosResponse,
        conferenciasResponse,
        aprovacoesResponse,
        retrabalhosResponse,
      ] = await Promise.all([
        supabase
          .from('dependencias')
          .select('*')
          .eq('execucao_id', execucaoId)
          .order('iniciado_em', { ascending: false }),

        supabase
          .from('bloqueios')
          .select('*')
          .eq('execucao_id', execucaoId)
          .order('iniciado_em', { ascending: false }),

        supabase
          .from('conferencias')
          .select(`
            *,
            conferente:pessoas(nome)
          `)
          .eq('execucao_id', execucaoId)
          .order('iniciado_em', { ascending: false }),

        supabase
          .from('aprovacoes')
          .select(`
            *,
            aprovador:pessoas(nome)
          `)
          .eq('execucao_id', execucaoId)
          .order('solicitado_em', { ascending: false }),

        supabase
          .from('retrabalhos')
          .select(`
            *,
            responsavel_correcao:pessoas!retrabalhos_responsavel_correcao_id_fkey(
              nome
            )
          `)
          .eq('execucao_id', execucaoId)
          .order('iniciado_em', { ascending: false }),
      ])

      if (dependenciasResponse.error) throw dependenciasResponse.error
      if (bloqueiosResponse.error) throw bloqueiosResponse.error
      if (conferenciasResponse.error) throw conferenciasResponse.error
      if (aprovacoesResponse.error) throw aprovacoesResponse.error
      if (retrabalhosResponse.error) throw retrabalhosResponse.error

      setDependencias(
        (dependenciasResponse.data || []) as Dependencia[]
      )

      setBloqueios((bloqueiosResponse.data || []) as Bloqueio[])

      setConferencias(
        (conferenciasResponse.data || []).map((item: any) => ({
          ...item,
          conferente: normalizarRelacao(item.conferente),
        })) as Conferencia[]
      )

      setAprovacoes(
        (aprovacoesResponse.data || []).map((item: any) => ({
          ...item,
          aprovador: normalizarRelacao(item.aprovador),
        })) as Aprovacao[]
      )

      setRetrabalhos(
        (retrabalhosResponse.data || []).map((item: any) => ({
          ...item,
          responsavel_correcao: normalizarRelacao(
            item.responsavel_correcao
          ),
        })) as Retrabalho[]
      )
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao carregar detalhes.')
    }
  }

  useEffect(() => {
    carregarBase()
  }, [])

  async function abrirExecucao(item: Execucao) {
    setSelecionada(item)
    await carregarDetalhes(item.id)
  }

  function prepararNovaExecucao() {
    setNovaOperacaoId('')
    setNovoResponsavelId(usuario.pessoaId)
    setNovoTitulo('')
    setNovaDescricao('')
    setNovaDataPrevista('')
    setNovaPrioridade('NORMAL')
    setMostrarNova(true)
  }

  function alterarOperacaoNova(id: string) {
    setNovaOperacaoId(id)

    const operacao = operacoes.find((x) => x.id === id)

    if (operacao) {
      setNovoTitulo(operacao.nome)
      setNovaPrioridade(operacao.prioridade || 'NORMAL')
    }
  }

  async function criarExecucao(e: React.FormEvent) {
    e.preventDefault()

    if (!novaOperacaoId || !novoResponsavelId || !novoTitulo.trim()) {
      setMensagem('Informe operação, responsável e título.')
      return
    }

    try {
      const { data, error } = await supabase
        .from('execucoes')
        .insert({
          operacao_id: novaOperacaoId,
          responsavel_id: novoResponsavelId,
          titulo: novoTitulo.trim(),
          descricao: novaDescricao.trim() || null,
          status: 'NAO_INICIADA',
          prioridade: novaPrioridade,
          data_prevista: novaDataPrevista
            ? new Date(novaDataPrevista).toISOString()
            : null,
          percentual_conclusao: 0,
        })
        .select('id')
        .single()

      if (error) throw error

      await supabase.from('execucao_participantes').insert({
        execucao_id: data.id,
        pessoa_id: novoResponsavelId,
        papel: 'RESPONSAVEL',
        ativo: true,
      })

      setMostrarNova(false)
      setMensagem('Execução criada com sucesso.')
      await carregarBase()
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Não foi possível criar a execução.')
    }
  }

  async function alterarStatus(novoStatus: string) {
    if (!selecionada) return

    try {
      const statusAnterior = selecionada.status
      const agora = new Date().toISOString()

      const atualizacao: any = {
        status: novoStatus,
        updated_at: agora,
      }

      if (
        novoStatus === 'EM_EXECUCAO' &&
        !selecionada.data_inicio
      ) {
        atualizacao.data_inicio = agora
      }

      if (novoStatus === 'CONCLUIDA') {
        atualizacao.data_conclusao = agora
        atualizacao.percentual_conclusao = 100
      }

      const { error } = await supabase
        .from('execucoes')
        .update(atualizacao)
        .eq('id', selecionada.id)

      if (error) throw error

      const { error: historicoError } = await supabase
        .from('execucao_status_historico')
        .insert({
          execucao_id: selecionada.id,
          status_anterior: statusAnterior,
          status_novo: novoStatus,
          alterado_por: usuario.pessoaId,
          motivo: 'Alteração realizada pela tela operacional',
        })

      if (historicoError) throw historicoError

      setMensagem('Status atualizado.')
      await carregarBase()
      await carregarDetalhes(selecionada.id)
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Não foi possível atualizar o status.')
    }
  }

  async function alterarProgresso(valor: number) {
    if (!selecionada) return

    try {
      const percentual = Math.max(0, Math.min(100, valor))

      const { error } = await supabase
        .from('execucoes')
        .update({
          percentual_conclusao: percentual,
          updated_at: new Date().toISOString(),
        })
        .eq('id', selecionada.id)

      if (error) throw error

      await carregarBase()
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao atualizar progresso.')
    }
  }

  async function criarDependencia(e: React.FormEvent) {
    e.preventDefault()

    if (!selecionada || !dependenciaMotivo.trim()) return

    try {
      const { error } = await supabase.from('dependencias').insert({
        execucao_id: selecionada.id,
        tipo_dependencia: dependenciaTipo,
        motivo: dependenciaMotivo.trim(),
        descricao: dependenciaDescricao.trim() || null,
        impacto: dependenciaImpacto,
        previsao_retorno: dependenciaPrevisao
          ? new Date(dependenciaPrevisao).toISOString()
          : null,
        proxima_acao: dependenciaProximaAcao.trim() || null,
        ativo: true,
      })

      if (error) throw error

      setDependenciaMotivo('')
      setDependenciaDescricao('')
      setDependenciaPrevisao('')
      setDependenciaProximaAcao('')

      setMensagem('Dependência registrada.')
      await carregarDetalhes(selecionada.id)
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao registrar dependência.')
    }
  }

  async function finalizarDependencia(id: string) {
    if (!selecionada) return

    try {
      const { error } = await supabase
        .from('dependencias')
        .update({
          ativo: false,
          finalizado_em: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', id)

      if (error) throw error

      await carregarDetalhes(selecionada.id)
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao finalizar dependência.')
    }
  }

  async function criarBloqueio(e: React.FormEvent) {
    e.preventDefault()

    if (!selecionada || !bloqueioMotivo.trim()) return

    try {
      const agora = new Date().toISOString()

      const { error } = await supabase.from('bloqueios').insert({
        execucao_id: selecionada.id,
        motivo: bloqueioMotivo.trim(),
        descricao: bloqueioDescricao.trim() || null,
        criado_por: usuario.pessoaId,
        ativo: true,
      })

      if (error) throw error

      if (selecionada.status !== 'BLOQUEADA') {
        await supabase
          .from('execucoes')
          .update({
            status: 'BLOQUEADA',
            updated_at: agora,
          })
          .eq('id', selecionada.id)

        await supabase.from('execucao_status_historico').insert({
          execucao_id: selecionada.id,
          status_anterior: selecionada.status,
          status_novo: 'BLOQUEADA',
          alterado_por: usuario.pessoaId,
          motivo: bloqueioMotivo.trim(),
        })
      }

      setBloqueioMotivo('')
      setBloqueioDescricao('')

      setMensagem('Bloqueio registrado.')
      await carregarBase()
      await carregarDetalhes(selecionada.id)
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao registrar bloqueio.')
    }
  }

  async function resolverBloqueio(item: Bloqueio) {
    if (!selecionada) return

    const resolucao = prompt('Informe como o bloqueio foi resolvido:')

    if (!resolucao?.trim()) return

    try {
      const { error } = await supabase
        .from('bloqueios')
        .update({
          ativo: false,
          finalizado_em: new Date().toISOString(),
          resolucao: resolucao.trim(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', item.id)

      if (error) throw error

      setMensagem('Bloqueio resolvido.')
      await carregarDetalhes(selecionada.id)
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao resolver bloqueio.')
    }
  }

  async function solicitarConferencia(e: React.FormEvent) {
    e.preventDefault()

    if (!selecionada || !conferenteId) return

    try {
      const { error } = await supabase.from('conferencias').insert({
        execucao_id: selecionada.id,
        conferente_id: conferenteId,
        resultado: 'PENDENTE',
      })

      if (error) throw error

      await alterarStatus('AGUARDANDO_CONFERENCIA')
      setConferenteId('')
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao solicitar conferência.')
    }
  }

  async function responderConferencia(
    item: Conferencia,
    resultado: 'APROVADA' | 'REJEITADA'
  ) {
    if (!selecionada) return

    const observacao = prompt(
      resultado === 'REJEITADA'
        ? 'Informe o motivo da rejeição:'
        : 'Observação da conferência (opcional):'
    )

    if (resultado === 'REJEITADA' && !observacao?.trim()) return

    try {
      const { error } = await supabase
        .from('conferencias')
        .update({
          resultado,
          observacao: observacao?.trim() || null,
          finalizado_em: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', item.id)

      if (error) throw error

      if (resultado === 'APROVADA') {
        await alterarStatus('EM_EXECUCAO')
      }

      await carregarDetalhes(selecionada.id)
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao responder conferência.')
    }
  }

  async function solicitarAprovacao(e: React.FormEvent) {
    e.preventDefault()

    if (!selecionada || !aprovadorId) return

    try {
      const { error } = await supabase.from('aprovacoes').insert({
        execucao_id: selecionada.id,
        aprovador_id: aprovadorId,
        status: 'PENDENTE',
      })

      if (error) throw error

      await alterarStatus('AGUARDANDO_APROVACAO')
      setAprovadorId('')
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao solicitar aprovação.')
    }
  }

  async function responderAprovacao(
    item: Aprovacao,
    status: 'APROVADA' | 'REJEITADA'
  ) {
    if (!selecionada) return

    const observacao = prompt(
      status === 'REJEITADA'
        ? 'Informe o motivo da rejeição:'
        : 'Observação da aprovação (opcional):'
    )

    if (status === 'REJEITADA' && !observacao?.trim()) return

    try {
      const { error } = await supabase
        .from('aprovacoes')
        .update({
          status,
          observacao: observacao?.trim() || null,
          respondido_em: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', item.id)

      if (error) throw error

      if (status === 'APROVADA') {
        await alterarStatus('EM_EXECUCAO')
      }

      await carregarDetalhes(selecionada.id)
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao responder aprovação.')
    }
  }

  async function criarRetrabalho(e: React.FormEvent) {
    e.preventDefault()

    if (
      !selecionada ||
      !retrabalhoResponsavelId ||
      !retrabalhoMotivo.trim()
    ) {
      return
    }

    try {
      const numeroRetorno =
        retrabalhos.length > 0
          ? Math.max(...retrabalhos.map((x) => x.numero_retorno || 0)) + 1
          : 1

      const { error } = await supabase.from('retrabalhos').insert({
        execucao_id: selecionada.id,
        identificado_por: usuario.pessoaId,
        responsavel_correcao_id: retrabalhoResponsavelId,
        categoria: retrabalhoCategoria,
        motivo: retrabalhoMotivo.trim(),
        descricao: retrabalhoDescricao.trim() || null,
        status: 'PENDENTE',
        numero_retorno: numeroRetorno,
      })

      if (error) throw error

      setRetrabalhoResponsavelId('')
      setRetrabalhoMotivo('')
      setRetrabalhoDescricao('')

      await alterarStatus('EM_EXECUCAO')
      await carregarDetalhes(selecionada.id)

      setMensagem('Retrabalho registrado.')
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao registrar retrabalho.')
    }
  }

  async function concluirRetrabalho(item: Retrabalho) {
    if (!selecionada) return

    try {
      const { error } = await supabase
        .from('retrabalhos')
        .update({
          status: 'CORRIGIDO',
          corrigido_em: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', item.id)

      if (error) throw error

      await carregarDetalhes(selecionada.id)
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao concluir retrabalho.')
    }
  }

  async function concluirExecucao() {
    if (!selecionada) return

    const bloqueioAberto = bloqueios.some((x) => x.ativo)
    const retrabalhoAberto = retrabalhos.some(
      (x) => !['CORRIGIDO', 'CANCELADO'].includes(x.status)
    )

    if (bloqueioAberto) {
      setMensagem(
        'A execução possui bloqueio aberto. Resolva o bloqueio antes de concluir.'
      )
      return
    }

    if (retrabalhoAberto) {
      setMensagem(
        'A execução possui retrabalho pendente. Corrija antes de concluir.'
      )
      return
    }

    if (!confirm('Concluir esta execução?')) return

    await alterarStatus('CONCLUIDA')
  }

  const resumo = useMemo(() => {
    return {
      total: execucoes.filter(
        (x) => !['CONCLUIDA', 'CANCELADA'].includes(x.status)
      ).length,

      atrasadas: execucoes.filter(estaAtrasada).length,

      bloqueadas: execucoes.filter(
        (x) => x.status === 'BLOQUEADA'
      ).length,

      aguardando: execucoes.filter((x) =>
        x.status.startsWith('AGUARDANDO_')
      ).length,
    }
  }, [execucoes])

  return (
    <>
      <header className="topbar">
        <div>
          <h1>Operações</h1>
          <p>Execução, acompanhamento e controle operacional</p>
        </div>

        <div className="topbar-user">{usuario.nome}</div>
      </header>

      <div className="page-actions">
        <div />

        <button
          className="primary-button"
          onClick={prepararNovaExecucao}
        >
          + Nova execução
        </button>
      </div>

      {mensagem && (
        <div className="system-message">{mensagem}</div>
      )}

      <section className="cards-grid">
        <div className="metric-card">
          <div className="metric-title">Em aberto</div>
          <div className="metric-value">{resumo.total}</div>
        </div>

        <div className="metric-card">
          <div className="metric-title">Atrasadas</div>
          <div className="metric-value">{resumo.atrasadas}</div>
        </div>

        <div className="metric-card">
          <div className="metric-title">Bloqueadas</div>
          <div className="metric-value">{resumo.bloqueadas}</div>
        </div>

        <div className="metric-card">
          <div className="metric-title">Aguardando</div>
          <div className="metric-value">{resumo.aguardando}</div>
        </div>
      </section>

      {mostrarNova && (
        <section className="panel">
          <div className="panel-header">
            <h3>Nova execução</h3>
            <p>Criação manual de uma atividade operacional.</p>
          </div>

          <form className="sector-form" onSubmit={criarExecucao}>
            <div className="form-row">
              <div className="form-group">
                <label>Operação</label>

                <select
                  value={novaOperacaoId}
                  onChange={(e) =>
                    alterarOperacaoNova(e.target.value)
                  }
                  required
                >
                  <option value="">Selecione</option>

                  {operacoes.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.nome}
                    </option>
                  ))}
                </select>
              </div>

              <div className="form-group">
                <label>Responsável</label>

                <select
                  value={novoResponsavelId}
                  onChange={(e) =>
                    setNovoResponsavelId(e.target.value)
                  }
                  required
                >
                  <option value="">Selecione</option>

                  {pessoas.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.nome}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div className="form-group">
              <label>Título</label>

              <input
                value={novoTitulo}
                onChange={(e) => setNovoTitulo(e.target.value)}
                required
              />
            </div>

            <div className="form-group">
              <label>Descrição</label>

              <textarea
                rows={3}
                value={novaDescricao}
                onChange={(e) =>
                  setNovaDescricao(e.target.value)
                }
              />
            </div>

            <div className="form-row">
              <div className="form-group">
                <label>Prazo</label>

                <input
                  type="datetime-local"
                  value={novaDataPrevista}
                  onChange={(e) =>
                    setNovaDataPrevista(e.target.value)
                  }
                />
              </div>

              <div className="form-group">
                <label>Prioridade</label>

                <select
                  value={novaPrioridade}
                  onChange={(e) =>
                    setNovaPrioridade(e.target.value)
                  }
                >
                  <option>BAIXA</option>
                  <option>NORMAL</option>
                  <option>ALTA</option>
                  <option>CRITICA</option>
                </select>
              </div>
            </div>

            <div className="form-actions">
              <button
                type="button"
                className="secondary-button"
                onClick={() => setMostrarNova(false)}
              >
                Cancelar
              </button>

              <button className="primary-button">
                Criar execução
              </button>
            </div>
          </form>
        </section>
      )}

      <section className="panel">
        <div className="panel-header">
          <h3>Execuções</h3>
          <p>
            {carregando
              ? 'Carregando...'
              : `${execucoes.length} registros`}
          </p>
        </div>

        <div className="table-wrapper">
          <table className="operations-table">
            <thead>
              <tr>
                <th>Atividade</th>
                <th>Responsável</th>
                <th>Status</th>
                <th>Prioridade</th>
                <th>Prazo</th>
                <th>Progresso</th>
                <th></th>
              </tr>
            </thead>

            <tbody>
              {execucoes.map((item) => (
                <tr key={item.id}>
                  <td>
                    <strong>{item.titulo}</strong>

                    {estaAtrasada(item) && (
                      <div className="nexo-danger-text">
                        ATRASADA
                      </div>
                    )}
                  </td>

                  <td>{item.responsavel?.nome || '—'}</td>

                  <td>
                    {formatarStatus(item.status)}
                  </td>

                  <td>{item.prioridade}</td>

                  <td>{formatarData(item.data_prevista)}</td>

                  <td>{item.percentual_conclusao}%</td>

                  <td>
                    <button
                      className="table-action-button"
                      onClick={() => abrirExecucao(item)}
                    >
                      Abrir
                    </button>
                  </td>
                </tr>
              ))}

              {!carregando && execucoes.length === 0 && (
                <tr>
                  <td colSpan={7}>Nenhuma execução encontrada.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>

      {selecionada && (
        <section className="panel nexo-execution-panel">
          <div className="panel-header">
            <div>
              <h3>{selecionada.titulo}</h3>
              <p>
                Responsável:{' '}
                {selecionada.responsavel?.nome || '—'}
              </p>
            </div>

            <button
              className="secondary-button"
              onClick={() => setSelecionada(null)}
            >
              Fechar
            </button>
          </div>

          <div className="nexo-execution-summary">
            <div>
              <span>Status</span>
              <strong>
                {formatarStatus(selecionada.status)}
              </strong>
            </div>

            <div>
              <span>Prioridade</span>
              <strong>{selecionada.prioridade}</strong>
            </div>

            <div>
              <span>Prazo</span>
              <strong>
                {formatarData(selecionada.data_prevista)}
              </strong>
            </div>

            <div>
              <span>Progresso</span>
              <strong>
                {selecionada.percentual_conclusao}%
              </strong>
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label>Status</label>

              <select
                value={selecionada.status}
                onChange={(e) => alterarStatus(e.target.value)}
              >
                {STATUS.map((status) => (
                  <option key={status} value={status}>
                    {formatarStatus(status)}
                  </option>
                ))}
              </select>
            </div>

            <div className="form-group">
              <label>Percentual concluído</label>

              <input
                type="number"
                min="0"
                max="100"
                value={selecionada.percentual_conclusao}
                onChange={(e) =>
                  alterarProgresso(Number(e.target.value))
                }
              />
            </div>
          </div>

          <hr className="nexo-divider" />

          <h3>Dependências</h3>

          <form
            className="sector-form"
            onSubmit={criarDependencia}
          >
            <div className="form-row">
              <div className="form-group">
                <label>Tipo</label>

                <select
                  value={dependenciaTipo}
                  onChange={(e) =>
                    setDependenciaTipo(e.target.value)
                  }
                >
                  <option>PESSOA</option>
                  <option>SETOR</option>
                  <option>FORNECEDOR</option>
                  <option>CLIENTE</option>
                  <option>SISTEMA</option>
                  <option>INFORMACAO</option>
                  <option>APROVACAO</option>
                  <option>OUTRO</option>
                </select>
              </div>

              <div className="form-group">
                <label>Impacto</label>

                <select
                  value={dependenciaImpacto}
                  onChange={(e) =>
                    setDependenciaImpacto(e.target.value)
                  }
                >
                  <option>BAIXO</option>
                  <option>MEDIO</option>
                  <option>ALTO</option>
                  <option>CRITICO</option>
                </select>
              </div>
            </div>

            <div className="form-group">
              <label>Motivo</label>

              <input
                value={dependenciaMotivo}
                onChange={(e) =>
                  setDependenciaMotivo(e.target.value)
                }
                required
              />
            </div>

            <div className="form-group">
              <label>Descrição</label>

              <textarea
                rows={2}
                value={dependenciaDescricao}
                onChange={(e) =>
                  setDependenciaDescricao(e.target.value)
                }
              />
            </div>

            <div className="form-row">
              <div className="form-group">
                <label>Previsão de retorno</label>

                <input
                  type="datetime-local"
                  value={dependenciaPrevisao}
                  onChange={(e) =>
                    setDependenciaPrevisao(e.target.value)
                  }
                />
              </div>

              <div className="form-group">
                <label>Próxima ação</label>

                <input
                  value={dependenciaProximaAcao}
                  onChange={(e) =>
                    setDependenciaProximaAcao(e.target.value)
                  }
                />
              </div>
            </div>

            <button className="primary-button">
              Registrar dependência
            </button>
          </form>

          <div className="nexo-record-list">
            {dependencias.map((item) => (
              <div className="nexo-record" key={item.id}>
                <div>
                  <strong>{item.motivo}</strong>
                  <p>
                    {item.tipo_dependencia} • {item.impacto}
                  </p>
                </div>

                <div>
                  {item.ativo ? (
                    <button
                      className="table-action-button success"
                      onClick={() =>
                        finalizarDependencia(item.id)
                      }
                    >
                      Finalizar
                    </button>
                  ) : (
                    <span>Finalizada</span>
                  )}
                </div>
              </div>
            ))}
          </div>

          <hr className="nexo-divider" />

          <h3>Bloqueios</h3>

          <form
            className="sector-form"
            onSubmit={criarBloqueio}
          >
            <div className="form-group">
              <label>Motivo do bloqueio</label>

              <input
                value={bloqueioMotivo}
                onChange={(e) =>
                  setBloqueioMotivo(e.target.value)
                }
                required
              />
            </div>

            <div className="form-group">
              <label>Descrição</label>

              <textarea
                rows={2}
                value={bloqueioDescricao}
                onChange={(e) =>
                  setBloqueioDescricao(e.target.value)
                }
              />
            </div>

            <button className="primary-button">
              Bloquear execução
            </button>
          </form>

          <div className="nexo-record-list">
            {bloqueios.map((item) => (
              <div className="nexo-record" key={item.id}>
                <div>
                  <strong>{item.motivo}</strong>
                  <p>{item.descricao || 'Sem descrição'}</p>
                </div>

                {item.ativo ? (
                  <button
                    className="table-action-button success"
                    onClick={() => resolverBloqueio(item)}
                  >
                    Resolver
                  </button>
                ) : (
                  <span>Resolvido</span>
                )}
              </div>
            ))}
          </div>

          <hr className="nexo-divider" />

          <h3>Conferência</h3>

          <form
            className="nexo-inline-form"
            onSubmit={solicitarConferencia}
          >
            <select
              value={conferenteId}
              onChange={(e) =>
                setConferenteId(e.target.value)
              }
              required
            >
              <option value="">Selecione o conferente</option>

              {pessoas.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.nome}
                </option>
              ))}
            </select>

            <button className="primary-button">
              Solicitar conferência
            </button>
          </form>

          <div className="nexo-record-list">
            {conferencias.map((item) => (
              <div className="nexo-record" key={item.id}>
                <div>
                  <strong>
                    {item.conferente?.nome || 'Conferente'}
                  </strong>
                  <p>{item.resultado}</p>
                </div>

                {item.resultado === 'PENDENTE' && (
                  <div className="table-actions">
                    <button
                      className="table-action-button success"
                      onClick={() =>
                        responderConferencia(item, 'APROVADA')
                      }
                    >
                      Aprovar
                    </button>

                    <button
                      className="table-action-button danger"
                      onClick={() =>
                        responderConferencia(item, 'REJEITADA')
                      }
                    >
                      Rejeitar
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>

          <hr className="nexo-divider" />

          <h3>Aprovação</h3>

          <form
            className="nexo-inline-form"
            onSubmit={solicitarAprovacao}
          >
            <select
              value={aprovadorId}
              onChange={(e) =>
                setAprovadorId(e.target.value)
              }
              required
            >
              <option value="">Selecione o aprovador</option>

              {pessoas.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.nome}
                </option>
              ))}
            </select>

            <button className="primary-button">
              Solicitar aprovação
            </button>
          </form>

          <div className="nexo-record-list">
            {aprovacoes.map((item) => (
              <div className="nexo-record" key={item.id}>
                <div>
                  <strong>
                    {item.aprovador?.nome || 'Aprovador'}
                  </strong>
                  <p>{item.status}</p>
                </div>

                {item.status === 'PENDENTE' && (
                  <div className="table-actions">
                    <button
                      className="table-action-button success"
                      onClick={() =>
                        responderAprovacao(item, 'APROVADA')
                      }
                    >
                      Aprovar
                    </button>

                    <button
                      className="table-action-button danger"
                      onClick={() =>
                        responderAprovacao(item, 'REJEITADA')
                      }
                    >
                      Rejeitar
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>

          <hr className="nexo-divider" />

          <h3>Retrabalho</h3>

          <form
            className="sector-form"
            onSubmit={criarRetrabalho}
          >
            <div className="form-row">
              <div className="form-group">
                <label>Responsável pela correção</label>

                <select
                  value={retrabalhoResponsavelId}
                  onChange={(e) =>
                    setRetrabalhoResponsavelId(
                      e.target.value
                    )
                  }
                  required
                >
                  <option value="">Selecione</option>

                  {pessoas.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.nome}
                    </option>
                  ))}
                </select>
              </div>

              <div className="form-group">
                <label>Categoria</label>

                <select
                  value={retrabalhoCategoria}
                  onChange={(e) =>
                    setRetrabalhoCategoria(e.target.value)
                  }
                >
                  <option>INFORMACAO_INCORRETA</option>
                  <option>INFORMACAO_INCOMPLETA</option>
                  <option>ERRO_EXECUCAO</option>
                  <option>DOCUMENTO_INCORRETO</option>
                  <option>FALTA_DOCUMENTO</option>
                  <option>DESCUMPRIMENTO_PROCEDIMENTO</option>
                  <option>OUTRO</option>
                </select>
              </div>
            </div>

            <div className="form-group">
              <label>Motivo</label>

              <input
                value={retrabalhoMotivo}
                onChange={(e) =>
                  setRetrabalhoMotivo(e.target.value)
                }
                required
              />
            </div>

            <div className="form-group">
              <label>Descrição</label>

              <textarea
                rows={2}
                value={retrabalhoDescricao}
                onChange={(e) =>
                  setRetrabalhoDescricao(e.target.value)
                }
              />
            </div>

            <button className="primary-button">
              Registrar retrabalho
            </button>
          </form>

          <div className="nexo-record-list">
            {retrabalhos.map((item) => (
              <div className="nexo-record" key={item.id}>
                <div>
                  <strong>
                    Retorno #{item.numero_retorno} —{' '}
                    {item.categoria}
                  </strong>

                  <p>
                    {item.responsavel_correcao?.nome || '—'} •{' '}
                    {item.status}
                  </p>

                  <p>{item.motivo}</p>
                </div>

                {!['CORRIGIDO', 'CANCELADO'].includes(
                  item.status
                ) && (
                  <button
                    className="table-action-button success"
                    onClick={() => concluirRetrabalho(item)}
                  >
                    Marcar corrigido
                  </button>
                )}
              </div>
            ))}
          </div>

          <div className="nexo-conclude-area">
            <button
              className="primary-button"
              onClick={concluirExecucao}
              disabled={
                selecionada.status === 'CONCLUIDA' ||
                selecionada.status === 'CANCELADA'
              }
            >
              Concluir execução
            </button>
          </div>
        </section>
      )}
    </>
  )
}
