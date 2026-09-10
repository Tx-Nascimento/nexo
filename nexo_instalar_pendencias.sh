#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/nexo/nexo
mkdir -p src/pages

cat > 'src/pages/CentralPage.tsx' <<'NEXO_EOF_SRC_PAGES_CENTRALPAGE_TSX'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario, Pagina } from '../types'

type Props = {
  usuario: DadosUsuario
  navegar: (pagina: Pagina) => void
}

type Execucao = {
  id: string
  titulo: string
  status: string
  prioridade: string
  data_prevista: string | null
  percentual_conclusao: number
  responsavel_id: string | null
}

type Demanda = {
  id: string
  titulo: string
  status: string
  prioridade: string
  data_prevista: string | null
  percentual_conclusao: number
  solicitante_id: string
  responsavel_id: string | null
}

function atrasada(data: string | null, status: string) {
  if (!data || ['CONCLUIDA', 'CANCELADA'].includes(status)) return false
  return new Date(data).getTime() < Date.now()
}

function statusLabel(status: string) {
  return status.replaceAll('_', ' ')
}

export default function CentralPage({ usuario, navegar }: Props) {
  const [execucoes, setExecucoes] = useState<Execucao[]>([])
  const [demandas, setDemandas] = useState<Demanda[]>([])
  const [carregando, setCarregando] = useState(true)
  const [mensagem, setMensagem] = useState('')

  useEffect(() => {
    async function carregar() {
      try {
        setCarregando(true)
        setMensagem('')

        const [execDiretas, participacoes, demandasResp, demandasSolic] = await Promise.all([
          supabase
            .from('execucoes')
            .select('id,titulo,status,prioridade,data_prevista,percentual_conclusao,responsavel_id,operacao:operacoes!inner(empresa_id)')
            .eq('operacao.empresa_id', usuario.empresaId)
            .eq('responsavel_id', usuario.pessoaId)
            .neq('status', 'CONCLUIDA')
            .neq('status', 'CANCELADA'),

          supabase
            .from('execucao_participantes')
            .select('execucao:execucoes!inner(id,titulo,status,prioridade,data_prevista,percentual_conclusao,responsavel_id,operacao:operacoes!inner(empresa_id))')
            .eq('pessoa_id', usuario.pessoaId)
            .eq('ativo', true)
            .eq('execucao.operacao.empresa_id', usuario.empresaId),

          supabase
            .from('demandas')
            .select('id,titulo,status,prioridade,data_prevista,percentual_conclusao,solicitante_id,responsavel_id')
            .eq('empresa_id', usuario.empresaId)
            .eq('responsavel_id', usuario.pessoaId)
            .neq('status', 'CONCLUIDA')
            .neq('status', 'CANCELADA'),

          supabase
            .from('demandas')
            .select('id,titulo,status,prioridade,data_prevista,percentual_conclusao,solicitante_id,responsavel_id')
            .eq('empresa_id', usuario.empresaId)
            .eq('solicitante_id', usuario.pessoaId)
            .neq('status', 'CONCLUIDA')
            .neq('status', 'CANCELADA'),
        ])

        for (const resposta of [execDiretas, participacoes, demandasResp, demandasSolic]) {
          if (resposta.error) throw resposta.error
        }

        const mapaExecucoes = new Map<string, Execucao>()
        for (const item of execDiretas.data || []) {
          mapaExecucoes.set(item.id, item as unknown as Execucao)
        }
        for (const item of participacoes.data || []) {
          const execucao = Array.isArray(item.execucao) ? item.execucao[0] : item.execucao
          if (execucao && !['CONCLUIDA', 'CANCELADA'].includes(execucao.status)) {
            mapaExecucoes.set(execucao.id, execucao as unknown as Execucao)
          }
        }

        const mapaDemandas = new Map<string, Demanda>()
        for (const item of [...(demandasResp.data || []), ...(demandasSolic.data || [])]) {
          mapaDemandas.set(item.id, item as Demanda)
        }

        setExecucoes([...mapaExecucoes.values()])
        setDemandas([...mapaDemandas.values()])
      } catch (error: any) {
        console.error(error)
        setMensagem(error?.message || 'Erro ao carregar a central.')
      } finally {
        setCarregando(false)
      }
    }

    carregar()
  }, [usuario.empresaId, usuario.pessoaId])

  const resumo = useMemo(() => {
    const atrasadasExec = execucoes.filter((x) => atrasada(x.data_prevista, x.status)).length
    const atrasadasDem = demandas.filter((x) => atrasada(x.data_prevista, x.status)).length
    const bloqueadas = execucoes.filter((x) => x.status === 'BLOQUEADA').length + demandas.filter((x) => x.status === 'BLOQUEADA').length
    const aguardando = execucoes.filter((x) => x.status.startsWith('AGUARDANDO')).length + demandas.filter((x) => x.status === 'AGUARDANDO').length

    return {
      atividades: execucoes.length,
      demandas: demandas.length,
      atrasadas: atrasadasExec + atrasadasDem,
      bloqueadas,
      aguardando,
    }
  }, [execucoes, demandas])

  const prioridades = useMemo(() => {
    return [...execucoes]
      .sort((a, b) => {
        const peso: Record<string, number> = { CRITICA: 4, ALTA: 3, NORMAL: 2, BAIXA: 1 }
        const atrasoA = atrasada(a.data_prevista, a.status) ? 10 : 0
        const atrasoB = atrasada(b.data_prevista, b.status) ? 10 : 0
        return atrasoB + (peso[b.prioridade] || 0) - (atrasoA + (peso[a.prioridade] || 0))
      })
      .slice(0, 8)
  }, [execucoes])

  if (carregando) {
    return <section className="panel"><div className="empty-state">Carregando sua central...</div></section>
  }

  return (
    <>
      <header className="topbar">
        <div>
          <h1>Minha Central</h1>
          <p>O que exige sua ação agora.</p>
        </div>
        <div className="topbar-user">{usuario.nome}</div>
      </header>

      {mensagem && <div className="system-message">{mensagem}</div>}

      <section className="welcome">
        <h2>Olá, {usuario.nome}</h2>
        <p>Atividades, demandas, atrasos, bloqueios e pendências sob sua responsabilidade ou participação.</p>
      </section>

      <section className="cards-grid nexo-five-cards">
        <div className="status-card"><span className="card-label">Atividades</span><strong className="card-value">{resumo.atividades}</strong></div>
        <div className="status-card"><span className="card-label">Demandas</span><strong className="card-value">{resumo.demandas}</strong></div>
        <div className="status-card"><span className="card-label">Atrasadas</span><strong className="card-value">{resumo.atrasadas}</strong></div>
        <div className="status-card"><span className="card-label">Bloqueadas</span><strong className="card-value">{resumo.bloqueadas}</strong></div>
        <div className="status-card"><span className="card-label">Aguardando</span><strong className="card-value">{resumo.aguardando}</strong></div>
      </section>

      <section className="nexo-quick-actions">
        <button onClick={() => navegar('operacoes')}>Abrir Operações</button>
        <button onClick={() => navegar('demandas')}>Abrir Demandas</button>
        <button onClick={() => navegar('documentos')}>Abrir Documentos</button>
      </section>

      <section className="panel">
        <div className="panel-header"><h3>Prioridades</h3><p>Execuções que merecem atenção primeiro.</p></div>
        {prioridades.length === 0 ? (
          <div className="empty-state">Nenhuma atividade pendente.</div>
        ) : (
          <div className="table-wrapper">
            <table className="operations-table">
              <thead><tr><th>Atividade</th><th>Prioridade</th><th>Status</th><th>Prazo</th><th>Progresso</th></tr></thead>
              <tbody>
                {prioridades.map((item) => (
                  <tr key={item.id}>
                    <td><strong>{item.titulo}</strong>{atrasada(item.data_prevista, item.status) && <div className="nexo-danger-text">ATRASADA</div>}</td>
                    <td>{item.prioridade}</td>
                    <td>{statusLabel(item.status)}</td>
                    <td>{item.data_prevista ? new Date(item.data_prevista).toLocaleString('pt-BR') : 'Sem prazo'}</td>
                    <td>{item.percentual_conclusao}%</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  )
}
NEXO_EOF_SRC_PAGES_CENTRALPAGE_TSX

cat > 'src/pages/ProcessosGeralPage.tsx' <<'NEXO_EOF_SRC_PAGES_PROCESSOSGERALPAGE_TSX'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario } from '../types'

type Props = { usuario: DadosUsuario }

type Processo = { id: string; nome: string; descricao: string | null; setor?: { nome: string } | null }
type Operacao = { id: string; processo_id: string; nome: string; prioridade: string; ativo: boolean }
type Execucao = { id: string; operacao_id: string; status: string; data_prevista: string | null; percentual_conclusao: number }

type Responsabilidade = { operacao_id: string; pessoa?: { nome: string } | null; papel: string; principal: boolean; ativo: boolean }

function atrasada(x: Execucao) {
  return !!x.data_prevista && !['CONCLUIDA', 'CANCELADA'].includes(x.status) && new Date(x.data_prevista).getTime() < Date.now()
}

export default function ProcessosGeralPage({ usuario }: Props) {
  const [processos, setProcessos] = useState<Processo[]>([])
  const [operacoes, setOperacoes] = useState<Operacao[]>([])
  const [execucoes, setExecucoes] = useState<Execucao[]>([])
  const [responsabilidades, setResponsabilidades] = useState<Responsabilidade[]>([])
  const [selecionado, setSelecionado] = useState<string>('')
  const [mensagem, setMensagem] = useState('')

  useEffect(() => {
    async function carregar() {
      try {
        const [p, o, e, r] = await Promise.all([
          supabase.from('processos').select('id,nome,descricao,setor:setores(nome)').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
          supabase.from('operacoes').select('id,processo_id,nome,prioridade,ativo').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
          supabase.from('execucoes').select('id,operacao_id,status,data_prevista,percentual_conclusao,operacao:operacoes!inner(empresa_id)').eq('operacao.empresa_id', usuario.empresaId),
          supabase.from('operacao_responsaveis').select('operacao_id,papel,principal,ativo,pessoa:pessoas(nome),operacao:operacoes!inner(empresa_id)').eq('operacao.empresa_id', usuario.empresaId).eq('ativo', true),
        ])
        for (const x of [p, o, e, r]) if (x.error) throw x.error
        setProcessos((p.data || []) as Processo[])
        setOperacoes((o.data || []) as Operacao[])
        setExecucoes((e.data || []) as Execucao[])
        setResponsabilidades((r.data || []) as Responsabilidade[])
      } catch (error: any) {
        console.error(error)
        setMensagem(error?.message || 'Erro ao carregar processos.')
      }
    }
    carregar()
  }, [usuario.empresaId])

  const linhas = useMemo(() => processos.map((processo) => {
    const ops = operacoes.filter((o) => o.processo_id === processo.id)
    const ids = new Set(ops.map((o) => o.id))
    const ex = execucoes.filter((x) => ids.has(x.operacao_id))
    const abertas = ex.filter((x) => !['CONCLUIDA', 'CANCELADA'].includes(x.status))
    const progresso = abertas.length ? Math.round(abertas.reduce((s, x) => s + x.percentual_conclusao, 0) / abertas.length) : 0
    return {
      ...processo,
      operacoes: ops.length,
      abertas: abertas.length,
      atrasadas: abertas.filter(atrasada).length,
      bloqueadas: abertas.filter((x) => x.status === 'BLOQUEADA').length,
      progresso,
    }
  }), [processos, operacoes, execucoes])

  const processoAtual = linhas.find((x) => x.id === selecionado)
  const operacoesAtuais = operacoes.filter((x) => x.processo_id === selecionado)

  return (
    <>
      <header className="topbar"><div><h1>Processos</h1><p>Visão operacional de processo → operação → execução.</p></div><div className="topbar-user">{usuario.nome}</div></header>
      {mensagem && <div className="system-message">{mensagem}</div>}
      <section className="panel">
        <div className="panel-header"><h3>Mapa de processos</h3><p>Onde existem atividades, atraso, bloqueio e carga operacional.</p></div>
        <div className="table-wrapper">
          <table className="operations-table">
            <thead><tr><th>Processo</th><th>Setor</th><th>Operações</th><th>Em aberto</th><th>Atrasadas</th><th>Bloqueadas</th><th>Progresso</th><th></th></tr></thead>
            <tbody>
              {linhas.map((item) => (
                <tr key={item.id}>
                  <td><strong>{item.nome}</strong></td>
                  <td>{item.setor?.nome || '-'}</td>
                  <td>{item.operacoes}</td><td>{item.abertas}</td><td>{item.atrasadas}</td><td>{item.bloqueadas}</td><td>{item.progresso}%</td>
                  <td><button className="table-action-button" onClick={() => setSelecionado(item.id)}>Detalhar</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {processoAtual && (
        <section className="panel">
          <div className="panel-header"><h3>{processoAtual.nome}</h3><p>{processoAtual.descricao || 'Sem descrição cadastrada.'}</p></div>
          <div className="nexo-grid-cards">
            {operacoesAtuais.map((op) => {
              const ex = execucoes.filter((x) => x.operacao_id === op.id && !['CONCLUIDA', 'CANCELADA'].includes(x.status))
              const resp = responsabilidades.filter((x) => x.operacao_id === op.id && x.ativo)
              return (
                <div className="nexo-info-card" key={op.id}>
                  <h4>{op.nome}</h4>
                  <p><strong>Prioridade:</strong> {op.prioridade}</p>
                  <p><strong>Em aberto:</strong> {ex.length}</p>
                  <p><strong>Atrasadas:</strong> {ex.filter(atrasada).length}</p>
                  <p><strong>Responsáveis:</strong> {resp.map((x) => x.pessoa?.nome).filter(Boolean).join(', ') || 'Não definidos'}</p>
                </div>
              )
            })}
          </div>
        </section>
      )}
    </>
  )
}
NEXO_EOF_SRC_PAGES_PROCESSOSGERALPAGE_TSX

cat > 'src/pages/PessoasGeralPage.tsx' <<'NEXO_EOF_SRC_PAGES_PESSOASGERALPAGE_TSX'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario } from '../types'

type Props = { usuario: DadosUsuario }
type Pessoa = { id: string; nome: string; email: string | null; setor?: { nome: string } | null; cargo?: { nome: string } | null }
type Execucao = { id: string; responsavel_id: string | null; status: string; data_prevista: string | null; percentual_conclusao: number; operacao_id: string }
type Demanda = { id: string; responsavel_id: string | null; status: string; data_prevista: string | null }
type Carga = { pessoa_id: string; tempo_estimado_minutos: number | null; percentual_carga: number | null }
type Resp = { pessoa_id: string; operacao_id: string; papel: string; ativo: boolean }

function atrasada(data: string | null, status: string) {
  return !!data && !['CONCLUIDA', 'CANCELADA'].includes(status) && new Date(data).getTime() < Date.now()
}

export default function PessoasGeralPage({ usuario }: Props) {
  const [pessoas, setPessoas] = useState<Pessoa[]>([])
  const [execucoes, setExecucoes] = useState<Execucao[]>([])
  const [demandas, setDemandas] = useState<Demanda[]>([])
  const [carga, setCarga] = useState<Carga[]>([])
  const [responsabilidades, setResponsabilidades] = useState<Resp[]>([])
  const [mensagem, setMensagem] = useState('')

  useEffect(() => {
    async function carregar() {
      try {
        const [p, e, d, c, r] = await Promise.all([
          supabase.from('pessoas').select('id,nome,email,setor:setores(nome),cargo:cargos(nome)').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
          supabase.from('execucoes').select('id,responsavel_id,status,data_prevista,percentual_conclusao,operacao_id,operacao:operacoes!inner(empresa_id)').eq('operacao.empresa_id', usuario.empresaId),
          supabase.from('demandas').select('id,responsavel_id,status,data_prevista').eq('empresa_id', usuario.empresaId),
          supabase.from('carga_trabalho').select('pessoa_id,tempo_estimado_minutos,percentual_carga,pessoa:pessoas!inner(empresa_id)').eq('pessoa.empresa_id', usuario.empresaId),
          supabase.from('operacao_responsaveis').select('pessoa_id,operacao_id,papel,ativo,operacao:operacoes!inner(empresa_id)').eq('operacao.empresa_id', usuario.empresaId).eq('ativo', true),
        ])
        for (const x of [p, e, d, c, r]) if (x.error) throw x.error
        setPessoas((p.data || []) as Pessoa[])
        setExecucoes((e.data || []) as Execucao[])
        setDemandas((d.data || []) as Demanda[])
        setCarga((c.data || []) as Carga[])
        setResponsabilidades((r.data || []) as Resp[])
      } catch (error: any) {
        console.error(error)
        setMensagem(error?.message || 'Erro ao carregar pessoas.')
      }
    }
    carregar()
  }, [usuario.empresaId])

  const linhas = useMemo(() => pessoas.map((pessoa) => {
    const ex = execucoes.filter((x) => x.responsavel_id === pessoa.id && !['CONCLUIDA', 'CANCELADA'].includes(x.status))
    const dem = demandas.filter((x) => x.responsavel_id === pessoa.id && !['CONCLUIDA', 'CANCELADA'].includes(x.status))
    const cargas = carga.filter((x) => x.pessoa_id === pessoa.id)
    const respons = responsabilidades.filter((x) => x.pessoa_id === pessoa.id)
    return {
      ...pessoa,
      responsabilidades: respons.length,
      atividades: ex.length,
      demandas: dem.length,
      atrasadas: ex.filter((x) => atrasada(x.data_prevista, x.status)).length + dem.filter((x) => atrasada(x.data_prevista, x.status)).length,
      bloqueadas: ex.filter((x) => x.status === 'BLOQUEADA').length,
      minutos: cargas.reduce((s, x) => s + (x.tempo_estimado_minutos || 0), 0),
      cargaPercentual: Math.round(cargas.reduce((s, x) => s + (Number(x.percentual_carga) || 0), 0)),
    }
  }), [pessoas, execucoes, demandas, carga, responsabilidades])

  return (
    <>
      <header className="topbar"><div><h1>Pessoas</h1><p>Responsabilidades, carga e atuação operacional.</p></div><div className="topbar-user">{usuario.nome}</div></header>
      {mensagem && <div className="system-message">{mensagem}</div>}
      <section className="panel">
        <div className="panel-header"><h3>Visão de capacidade</h3><p>Quem está com demanda, atraso, bloqueio e responsabilidades fixas.</p></div>
        <div className="table-wrapper">
          <table className="operations-table">
            <thead><tr><th>Pessoa</th><th>Setor / Cargo</th><th>Responsabilidades</th><th>Atividades</th><th>Demandas</th><th>Atrasadas</th><th>Bloqueadas</th><th>Carga</th></tr></thead>
            <tbody>
              {linhas.map((item) => (
                <tr key={item.id}>
                  <td><strong>{item.nome}</strong><div className="nexo-muted">{item.email || ''}</div></td>
                  <td>{item.setor?.nome || '-'} / {item.cargo?.nome || '-'}</td>
                  <td>{item.responsabilidades}</td><td>{item.atividades}</td><td>{item.demandas}</td>
                  <td>{item.atrasadas}</td><td>{item.bloqueadas}</td>
                  <td>{item.cargaPercentual ? `${item.cargaPercentual}%` : `${item.minutos} min`}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  )
}
NEXO_EOF_SRC_PAGES_PESSOASGERALPAGE_TSX

cat > 'src/pages/DocumentosPage.tsx' <<'NEXO_EOF_SRC_PAGES_DOCUMENTOSPAGE_TSX'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario } from '../types'

type Props = { usuario: DadosUsuario }
type Setor = { id: string; nome: string }
type Pessoa = { id: string; nome: string }
type Processo = { id: string; nome: string }
type Operacao = { id: string; nome: string }
type Documento = {
  id: string
  titulo: string
  descricao: string | null
  tipo: string
  arquivo_url: string | null
  link_externo: string | null
  setor?: { nome: string } | null
  pessoa?: { nome: string } | null
  created_at: string
  ativo: boolean
}
type Procedimento = { id: string; operacao_id: string; titulo: string; descricao: string | null; versao_atual: number; ativo: boolean; operacao?: { nome: string } | null }
type Etapa = { id: string; ordem: number; titulo: string; descricao: string | null; obrigatoria: boolean }
type Execucao = { id: string; titulo: string }
type Evidencia = { id: string; execucao_id: string; tipo: string; titulo: string | null; descricao: string | null; valor_texto: string | null; arquivo_url: string | null; obrigatoria: boolean; created_at: string; execucao?: { titulo: string } | null }

const TIPOS = ['PROCEDIMENTO', 'POLITICA', 'MODELO', 'PLANILHA', 'CONTRATO', 'MANUAL', 'FORMULARIO', 'OUTRO']
const TIPOS_EVIDENCIA = ['ARQUIVO', 'IMAGEM', 'PDF', 'PLANILHA', 'LINK', 'TEXTO', 'NUMERO_DOCUMENTO', 'CHECKLIST', 'OUTRO']

export default function DocumentosPage({ usuario }: Props) {
  const [documentos, setDocumentos] = useState<Documento[]>([])
  const [procedimentos, setProcedimentos] = useState<Procedimento[]>([])
  const [setores, setSetores] = useState<Setor[]>([])
  const [pessoas, setPessoas] = useState<Pessoa[]>([])
  const [processos, setProcessos] = useState<Processo[]>([])
  const [operacoes, setOperacoes] = useState<Operacao[]>([])
  const [aba, setAba] = useState<'documentos' | 'procedimentos' | 'evidencias'>('documentos')
  const [execucoes, setExecucoes] = useState<Execucao[]>([])
  const [evidencias, setEvidencias] = useState<Evidencia[]>([])
  const [mensagem, setMensagem] = useState('')

  const [titulo, setTitulo] = useState('')
  const [descricao, setDescricao] = useState('')
  const [tipo, setTipo] = useState('OUTRO')
  const [setorId, setSetorId] = useState('')
  const [pessoaId, setPessoaId] = useState('')
  const [processoId, setProcessoId] = useState('')
  const [operacaoId, setOperacaoId] = useState('')
  const [link, setLink] = useState('')
  const [arquivo, setArquivo] = useState<File | null>(null)

  const [procOperacaoId, setProcOperacaoId] = useState('')
  const [procTitulo, setProcTitulo] = useState('')
  const [procDescricao, setProcDescricao] = useState('')
  const [procedimentoSelecionado, setProcedimentoSelecionado] = useState<Procedimento | null>(null)
  const [etapas, setEtapas] = useState<Etapa[]>([])
  const [etapaTitulo, setEtapaTitulo] = useState('')
  const [etapaDescricao, setEtapaDescricao] = useState('')

  const [evidenciaExecucaoId, setEvidenciaExecucaoId] = useState('')
  const [evidenciaTipo, setEvidenciaTipo] = useState('TEXTO')
  const [evidenciaTitulo, setEvidenciaTitulo] = useState('')
  const [evidenciaDescricao, setEvidenciaDescricao] = useState('')
  const [evidenciaValor, setEvidenciaValor] = useState('')
  const [evidenciaArquivo, setEvidenciaArquivo] = useState<File | null>(null)

  async function carregar() {
    try {
      const [d, pr, s, pe, p, o, ex, ev] = await Promise.all([
        supabase.from('documentos').select('id,titulo,descricao,tipo,arquivo_url,link_externo,created_at,ativo,setor:setores(nome),pessoa:pessoas(nome)').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('created_at', { ascending: false }),
        supabase.from('procedimentos').select('id,operacao_id,titulo,descricao,versao_atual,ativo,operacao:operacoes!inner(nome,empresa_id)').eq('operacao.empresa_id', usuario.empresaId).eq('ativo', true).order('titulo'),
        supabase.from('setores').select('id,nome').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
        supabase.from('pessoas').select('id,nome').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
        supabase.from('processos').select('id,nome').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
        supabase.from('operacoes').select('id,nome').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
        supabase.from('execucoes').select('id,titulo,operacao:operacoes!inner(empresa_id)').eq('operacao.empresa_id', usuario.empresaId).order('created_at', { ascending: false }),
        supabase.from('evidencias').select('id,execucao_id,tipo,titulo,descricao,valor_texto,arquivo_url,obrigatoria,created_at,execucao:execucoes!inner(titulo,operacao:operacoes!inner(empresa_id))').eq('execucao.operacao.empresa_id', usuario.empresaId).order('created_at', { ascending: false }),
      ])
      for (const x of [d, pr, s, pe, p, o, ex, ev]) if (x.error) throw x.error
      setDocumentos((d.data || []) as Documento[])
      setProcedimentos((pr.data || []) as Procedimento[])
      setSetores((s.data || []) as Setor[])
      setPessoas((pe.data || []) as Pessoa[])
      setProcessos((p.data || []) as Processo[])
      setOperacoes((o.data || []) as Operacao[])
      setExecucoes((ex.data || []) as Execucao[])
      setEvidencias((ev.data || []) as Evidencia[])
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao carregar documentos.')
    }
  }

  useEffect(() => { carregar() }, [usuario.empresaId])

  async function criarDocumento(e: React.FormEvent) {
    e.preventDefault()
    try {
      setMensagem('')
      let arquivoPath: string | null = null
      if (arquivo) {
        const seguro = arquivo.name.replace(/[^a-zA-Z0-9._-]/g, '_')
        arquivoPath = `${usuario.empresaId}/${crypto.randomUUID()}-${seguro}`
        const { error } = await supabase.storage.from('nexo-documentos').upload(arquivoPath, arquivo)
        if (error) throw error
      }

      const { data: doc, error } = await supabase.from('documentos').insert({
        empresa_id: usuario.empresaId,
        setor_id: setorId || null,
        pessoa_id: pessoaId || null,
        titulo: titulo.trim(),
        descricao: descricao.trim() || null,
        tipo,
        arquivo_url: arquivoPath,
        link_externo: link.trim() || null,
        ativo: true,
      }).select('id').single()
      if (error) throw error

      if (processoId || operacaoId) {
        const { error: vinculoError } = await supabase.from('documento_vinculos').insert({
          documento_id: doc.id,
          processo_id: processoId || null,
          operacao_id: operacaoId || null,
        })
        if (vinculoError) throw vinculoError
      }

      setTitulo(''); setDescricao(''); setTipo('OUTRO'); setSetorId(''); setPessoaId(''); setProcessoId(''); setOperacaoId(''); setLink(''); setArquivo(null)
      setMensagem('Documento cadastrado com sucesso.')
      await carregar()
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao salvar documento.')
    }
  }

  async function abrirDocumento(doc: Documento) {
    if (doc.link_externo) {
      window.open(doc.link_externo, '_blank', 'noopener,noreferrer')
      return
    }
    if (!doc.arquivo_url) return
    const { data, error } = await supabase.storage.from('nexo-documentos').createSignedUrl(doc.arquivo_url, 300)
    if (error) { setMensagem(error.message); return }
    window.open(data.signedUrl, '_blank', 'noopener,noreferrer')
  }

  async function criarProcedimento(e: React.FormEvent) {
    e.preventDefault()
    try {
      const { data: proc, error } = await supabase.from('procedimentos').insert({
        operacao_id: procOperacaoId,
        titulo: procTitulo.trim(),
        descricao: procDescricao.trim() || null,
        versao_atual: 1,
        ativo: true,
      }).select('id').single()
      if (error) throw error
      const { error: versaoError } = await supabase.from('procedimento_versoes').insert({ procedimento_id: proc.id, versao: 1, descricao_alteracao: 'Versão inicial', criado_por: usuario.pessoaId })
      if (versaoError) throw versaoError
      setProcOperacaoId(''); setProcTitulo(''); setProcDescricao('')
      setMensagem('Procedimento criado com sucesso.')
      await carregar()
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao criar procedimento.')
    }
  }

  async function abrirProcedimento(proc: Procedimento) {
    setProcedimentoSelecionado(proc)
    const { data: versao, error } = await supabase.from('procedimento_versoes').select('id').eq('procedimento_id', proc.id).eq('versao', proc.versao_atual).single()
    if (error) { setMensagem(error.message); return }
    const { data, error: etapasError } = await supabase.from('procedimento_etapas').select('id,ordem,titulo,descricao,obrigatoria').eq('procedimento_versao_id', versao.id).order('ordem')
    if (etapasError) { setMensagem(etapasError.message); return }
    setEtapas((data || []) as Etapa[])
  }

  async function adicionarEtapa(e: React.FormEvent) {
    e.preventDefault()
    if (!procedimentoSelecionado) return
    const { data: versao, error } = await supabase.from('procedimento_versoes').select('id').eq('procedimento_id', procedimentoSelecionado.id).eq('versao', procedimentoSelecionado.versao_atual).single()
    if (error) { setMensagem(error.message); return }
    const { error: etapaError } = await supabase.from('procedimento_etapas').insert({ procedimento_versao_id: versao.id, ordem: etapas.length + 1, titulo: etapaTitulo.trim(), descricao: etapaDescricao.trim() || null, obrigatoria: true })
    if (etapaError) { setMensagem(etapaError.message); return }
    setEtapaTitulo(''); setEtapaDescricao('')
    await abrirProcedimento(procedimentoSelecionado)
  }



  async function criarEvidencia(e: React.FormEvent) {
    e.preventDefault()
    try {
      setMensagem('')
      let arquivoPath: string | null = null
      if (evidenciaArquivo) {
        const seguro = evidenciaArquivo.name.replace(/[^a-zA-Z0-9._-]/g, '_')
        arquivoPath = `${usuario.empresaId}/evidencias/${crypto.randomUUID()}-${seguro}`
        const { error } = await supabase.storage.from('nexo-documentos').upload(arquivoPath, evidenciaArquivo)
        if (error) throw error
      }
      const { error } = await supabase.from('evidencias').insert({
        execucao_id: evidenciaExecucaoId,
        pessoa_id: usuario.pessoaId,
        tipo: evidenciaTipo,
        titulo: evidenciaTitulo.trim() || null,
        descricao: evidenciaDescricao.trim() || null,
        valor_texto: evidenciaValor.trim() || null,
        arquivo_url: arquivoPath,
        obrigatoria: false,
      })
      if (error) throw error
      setEvidenciaExecucaoId(''); setEvidenciaTipo('TEXTO'); setEvidenciaTitulo(''); setEvidenciaDescricao(''); setEvidenciaValor(''); setEvidenciaArquivo(null)
      setMensagem('Evidência registrada com sucesso.')
      await carregar()
    } catch (error: any) {
      console.error(error)
      setMensagem(error?.message || 'Erro ao registrar evidência.')
    }
  }

  async function abrirEvidencia(ev: Evidencia) {
    if (!ev.arquivo_url) return
    const { data, error } = await supabase.storage.from('nexo-documentos').createSignedUrl(ev.arquivo_url, 300)
    if (error) { setMensagem(error.message); return }
    window.open(data.signedUrl, '_blank', 'noopener,noreferrer')
  }

  const porTipo = useMemo(() => documentos.reduce<Record<string, number>>((acc, x) => { acc[x.tipo] = (acc[x.tipo] || 0) + 1; return acc }, {}), [documentos])

  return (
    <>
      <header className="topbar"><div><h1>Documentos</h1><p>Repositório, procedimentos e conhecimento operacional.</p></div><div className="topbar-user">{usuario.nome}</div></header>
      {mensagem && <div className="system-message">{mensagem}</div>}
      <div className="nexo-tabs"><button className={aba === 'documentos' ? 'active' : ''} onClick={() => setAba('documentos')}>Documentos</button><button className={aba === 'procedimentos' ? 'active' : ''} onClick={() => setAba('procedimentos')}>Procedimentos</button><button className={aba === 'evidencias' ? 'active' : ''} onClick={() => setAba('evidencias')}>Evidências</button></div>

      {aba === 'documentos' ? (
        <>
          <section className="cards-grid"><div className="status-card"><span className="card-label">Documentos ativos</span><strong className="card-value">{documentos.length}</strong></div><div className="status-card"><span className="card-label">Procedimentos</span><strong className="card-value">{porTipo.PROCEDIMENTO || 0}</strong></div><div className="status-card"><span className="card-label">Planilhas</span><strong className="card-value">{porTipo.PLANILHA || 0}</strong></div><div className="status-card"><span className="card-label">Manuais</span><strong className="card-value">{porTipo.MANUAL || 0}</strong></div></section>
          <section className="panel nexo-form-panel"><div className="panel-header"><h3>Novo documento</h3><p>O arquivo é armazenado no repositório privado do NEXO.</p></div><form className="sector-form" onSubmit={criarDocumento}>
            <div className="form-row"><div className="form-group"><label>Título</label><input value={titulo} onChange={(e) => setTitulo(e.target.value)} required /></div><div className="form-group"><label>Tipo</label><select value={tipo} onChange={(e) => setTipo(e.target.value)}>{TIPOS.map((x) => <option key={x}>{x}</option>)}</select></div></div>
            <div className="form-group"><label>Descrição</label><textarea value={descricao} onChange={(e) => setDescricao(e.target.value)} rows={3} /></div>
            <div className="form-row"><div className="form-group"><label>Setor</label><select value={setorId} onChange={(e) => setSetorId(e.target.value)}><option value="">Empresa</option>{setores.map((x) => <option key={x.id} value={x.id}>{x.nome}</option>)}</select></div><div className="form-group"><label>Pessoa</label><select value={pessoaId} onChange={(e) => setPessoaId(e.target.value)}><option value="">Sem pessoa específica</option>{pessoas.map((x) => <option key={x.id} value={x.id}>{x.nome}</option>)}</select></div></div>
            <div className="form-row"><div className="form-group"><label>Processo</label><select value={processoId} onChange={(e) => setProcessoId(e.target.value)}><option value="">Sem vínculo</option>{processos.map((x) => <option key={x.id} value={x.id}>{x.nome}</option>)}</select></div><div className="form-group"><label>Operação</label><select value={operacaoId} onChange={(e) => setOperacaoId(e.target.value)}><option value="">Sem vínculo</option>{operacoes.map((x) => <option key={x.id} value={x.id}>{x.nome}</option>)}</select></div></div>
            <div className="form-row"><div className="form-group"><label>Arquivo</label><input type="file" onChange={(e) => setArquivo(e.target.files?.[0] || null)} /></div><div className="form-group"><label>Link externo</label><input value={link} onChange={(e) => setLink(e.target.value)} placeholder="https://..." /></div></div>
            <div className="form-actions"><button className="table-action-button success" type="submit">Salvar documento</button></div>
          </form></section>
          <section className="panel"><div className="panel-header"><h3>Repositório</h3><p>Arquivos da empresa, setores e pessoas.</p></div><div className="table-wrapper"><table className="operations-table"><thead><tr><th>Título</th><th>Tipo</th><th>Setor</th><th>Pessoa</th><th>Data</th><th></th></tr></thead><tbody>{documentos.map((doc) => <tr key={doc.id}><td><strong>{doc.titulo}</strong><div className="nexo-muted">{doc.descricao || ''}</div></td><td>{doc.tipo}</td><td>{doc.setor?.nome || 'Empresa'}</td><td>{doc.pessoa?.nome || '-'}</td><td>{new Date(doc.created_at).toLocaleDateString('pt-BR')}</td><td><button className="table-action-button" onClick={() => abrirDocumento(doc)} disabled={!doc.arquivo_url && !doc.link_externo}>Abrir</button></td></tr>)}</tbody></table></div></section>
        </>
      ) : aba === 'procedimentos' ? (
        <>
          <section className="panel nexo-form-panel"><div className="panel-header"><h3>Novo procedimento</h3><p>Padronize como uma operação deve ser executada.</p></div><form className="sector-form" onSubmit={criarProcedimento}><div className="form-row"><div className="form-group"><label>Operação</label><select value={procOperacaoId} onChange={(e) => setProcOperacaoId(e.target.value)} required><option value="">Selecione</option>{operacoes.map((x) => <option key={x.id} value={x.id}>{x.nome}</option>)}</select></div><div className="form-group"><label>Título</label><input value={procTitulo} onChange={(e) => setProcTitulo(e.target.value)} required /></div></div><div className="form-group"><label>Descrição</label><textarea rows={3} value={procDescricao} onChange={(e) => setProcDescricao(e.target.value)} /></div><div className="form-actions"><button className="table-action-button success">Criar procedimento</button></div></form></section>
          <section className="panel"><div className="panel-header"><h3>Procedimentos</h3></div><div className="table-wrapper"><table className="operations-table"><thead><tr><th>Procedimento</th><th>Operação</th><th>Versão</th><th></th></tr></thead><tbody>{procedimentos.map((p) => <tr key={p.id}><td><strong>{p.titulo}</strong></td><td>{p.operacao?.nome || '-'}</td><td>{p.versao_atual}</td><td><button className="table-action-button" onClick={() => abrirProcedimento(p)}>Etapas</button></td></tr>)}</tbody></table></div></section>
          {procedimentoSelecionado && <section className="panel"><div className="panel-header"><h3>{procedimentoSelecionado.titulo}</h3><p>Versão {procedimentoSelecionado.versao_atual}</p></div><div className="nexo-record-list nexo-pad">{etapas.map((e) => <div className="nexo-record" key={e.id}><div><strong>{e.ordem}. {e.titulo}</strong><p>{e.descricao || ''}</p></div><span>{e.obrigatoria ? 'Obrigatória' : 'Opcional'}</span></div>)}</div><form className="sector-form" onSubmit={adicionarEtapa}><div className="form-row"><div className="form-group"><label>Nova etapa</label><input value={etapaTitulo} onChange={(e) => setEtapaTitulo(e.target.value)} required /></div><div className="form-group"><label>Descrição</label><input value={etapaDescricao} onChange={(e) => setEtapaDescricao(e.target.value)} /></div></div><div className="form-actions"><button className="table-action-button success">Adicionar etapa</button></div></form></section>}
        </>
      ) : (
        <>
          <section className="panel nexo-form-panel"><div className="panel-header"><h3>Nova evidência</h3><p>Comprove uma execução com arquivo, texto, link ou número de documento.</p></div><form className="sector-form" onSubmit={criarEvidencia}><div className="form-row"><div className="form-group"><label>Execução</label><select value={evidenciaExecucaoId} onChange={(e) => setEvidenciaExecucaoId(e.target.value)} required><option value="">Selecione</option>{execucoes.map((x) => <option key={x.id} value={x.id}>{x.titulo}</option>)}</select></div><div className="form-group"><label>Tipo</label><select value={evidenciaTipo} onChange={(e) => setEvidenciaTipo(e.target.value)}>{TIPOS_EVIDENCIA.map((x) => <option key={x}>{x}</option>)}</select></div></div><div className="form-row"><div className="form-group"><label>Título</label><input value={evidenciaTitulo} onChange={(e) => setEvidenciaTitulo(e.target.value)} /></div><div className="form-group"><label>Valor / link / nº documento</label><input value={evidenciaValor} onChange={(e) => setEvidenciaValor(e.target.value)} /></div></div><div className="form-group"><label>Descrição</label><textarea rows={3} value={evidenciaDescricao} onChange={(e) => setEvidenciaDescricao(e.target.value)} /></div><div className="form-group"><label>Arquivo</label><input type="file" onChange={(e) => setEvidenciaArquivo(e.target.files?.[0] || null)} /></div><div className="form-actions"><button className="table-action-button success">Registrar evidência</button></div></form></section>
          <section className="panel"><div className="panel-header"><h3>Evidências registradas</h3></div><div className="table-wrapper"><table className="operations-table"><thead><tr><th>Execução</th><th>Tipo</th><th>Título</th><th>Data</th><th></th></tr></thead><tbody>{evidencias.map((ev) => <tr key={ev.id}><td><strong>{ev.execucao?.titulo || ev.execucao_id}</strong></td><td>{ev.tipo}</td><td>{ev.titulo || ev.valor_texto || '-'}</td><td>{new Date(ev.created_at).toLocaleString('pt-BR')}</td><td><button className="table-action-button" disabled={!ev.arquivo_url} onClick={() => abrirEvidencia(ev)}>Abrir arquivo</button></td></tr>)}</tbody></table></div></section>
        </>
      )}
    </>
  )
}
NEXO_EOF_SRC_PAGES_DOCUMENTOSPAGE_TSX

cat > 'src/pages/IndicadoresPage.tsx' <<'NEXO_EOF_SRC_PAGES_INDICADORESPAGE_TSX'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario } from '../types'

type Props = { usuario: DadosUsuario }
type Execucao = { id: string; status: string; data_prevista: string | null; data_inicio: string | null; data_conclusao: string | null; responsavel_id: string | null; operacao_id: string }
type Retrabalho = { id: string; execucao_id: string; status: string; iniciado_em: string; corrigido_em: string | null }
type Bloqueio = { id: string; execucao_id: string; iniciado_em: string; finalizado_em: string | null; ativo: boolean }
type Dependencia = { id: string; execucao_id: string; iniciado_em: string; finalizado_em: string | null; ativo: boolean }
type Pessoa = { id: string; nome: string }

function atrasada(x: Execucao) {
  return !!x.data_prevista && !['CONCLUIDA', 'CANCELADA'].includes(x.status) && new Date(x.data_prevista).getTime() < Date.now()
}

function horasEntre(inicio: string, fim: string | null) {
  return Math.max(0, ((fim ? new Date(fim).getTime() : Date.now()) - new Date(inicio).getTime()) / 3600000)
}

export default function IndicadoresPage({ usuario }: Props) {
  const [execucoes, setExecucoes] = useState<Execucao[]>([])
  const [retrabalhos, setRetrabalhos] = useState<Retrabalho[]>([])
  const [bloqueios, setBloqueios] = useState<Bloqueio[]>([])
  const [dependencias, setDependencias] = useState<Dependencia[]>([])
  const [pessoas, setPessoas] = useState<Pessoa[]>([])
  const [mensagem, setMensagem] = useState('')

  useEffect(() => {
    async function carregar() {
      try {
        const [e, r, b, d, p] = await Promise.all([
          supabase.from('execucoes').select('id,status,data_prevista,data_inicio,data_conclusao,responsavel_id,operacao_id,operacao:operacoes!inner(empresa_id)').eq('operacao.empresa_id', usuario.empresaId),
          supabase.from('retrabalhos').select('id,execucao_id,status,iniciado_em,corrigido_em,execucao:execucoes!inner(operacao:operacoes!inner(empresa_id))').eq('execucao.operacao.empresa_id', usuario.empresaId),
          supabase.from('bloqueios').select('id,execucao_id,iniciado_em,finalizado_em,ativo,execucao:execucoes!inner(operacao:operacoes!inner(empresa_id))').eq('execucao.operacao.empresa_id', usuario.empresaId),
          supabase.from('dependencias').select('id,execucao_id,iniciado_em,finalizado_em,ativo,execucao:execucoes!inner(operacao:operacoes!inner(empresa_id))').eq('execucao.operacao.empresa_id', usuario.empresaId),
          supabase.from('pessoas').select('id,nome').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
        ])
        for (const x of [e, r, b, d, p]) if (x.error) throw x.error
        setExecucoes((e.data || []) as Execucao[])
        setRetrabalhos((r.data || []) as Retrabalho[])
        setBloqueios((b.data || []) as Bloqueio[])
        setDependencias((d.data || []) as Dependencia[])
        setPessoas((p.data || []) as Pessoa[])
      } catch (error: any) {
        console.error(error)
        setMensagem(error?.message || 'Erro ao carregar indicadores.')
      }
    }
    carregar()
  }, [usuario.empresaId])

  const kpis = useMemo(() => {
    const concluidas = execucoes.filter((x) => x.status === 'CONCLUIDA')
    const concluidasNoPrazo = concluidas.filter((x) => !x.data_prevista || !x.data_conclusao || new Date(x.data_conclusao) <= new Date(x.data_prevista)).length
    const tempoMedio = concluidas.filter((x) => x.data_inicio && x.data_conclusao).map((x) => horasEntre(x.data_inicio!, x.data_conclusao)).reduce((a, b, _, arr) => a + b / arr.length, 0)
    return {
      total: execucoes.length,
      abertas: execucoes.filter((x) => !['CONCLUIDA', 'CANCELADA'].includes(x.status)).length,
      atrasadas: execucoes.filter(atrasada).length,
      noPrazo: concluidas.length ? Math.round((concluidasNoPrazo / concluidas.length) * 100) : 0,
      retrabalho: retrabalhos.length,
      bloqueiosAtivos: bloqueios.filter((x) => x.ativo).length,
      dependenciasAtivas: dependencias.filter((x) => x.ativo).length,
      tempoMedio: Math.round(tempoMedio * 10) / 10,
      horasBloqueadas: Math.round(bloqueios.reduce((s, x) => s + horasEntre(x.iniciado_em, x.finalizado_em), 0) * 10) / 10,
    }
  }, [execucoes, retrabalhos, bloqueios, dependencias])

  const porPessoa = useMemo(() => pessoas.map((p) => {
    const ex = execucoes.filter((x) => x.responsavel_id === p.id)
    const abertas = ex.filter((x) => !['CONCLUIDA', 'CANCELADA'].includes(x.status))
    const concluidas = ex.filter((x) => x.status === 'CONCLUIDA')
    return { ...p, abertas: abertas.length, atrasadas: abertas.filter(atrasada).length, concluidas: concluidas.length }
  }).filter((x) => x.abertas || x.concluidas), [pessoas, execucoes])

  return (
    <>
      <header className="topbar"><div><h1>Indicadores</h1><p>Prazo, qualidade, fluxo, bloqueios e produtividade.</p></div><div className="topbar-user">{usuario.nome}</div></header>
      {mensagem && <div className="system-message">{mensagem}</div>}
      <section className="cards-grid nexo-kpi-grid">
        <div className="status-card"><span className="card-label">Em aberto</span><strong className="card-value">{kpis.abertas}</strong></div>
        <div className="status-card"><span className="card-label">Atrasadas</span><strong className="card-value">{kpis.atrasadas}</strong></div>
        <div className="status-card"><span className="card-label">Concluídas no prazo</span><strong className="card-value">{kpis.noPrazo}%</strong></div>
        <div className="status-card"><span className="card-label">Retrabalhos</span><strong className="card-value">{kpis.retrabalho}</strong></div>
        <div className="status-card"><span className="card-label">Bloqueios ativos</span><strong className="card-value">{kpis.bloqueiosAtivos}</strong></div>
        <div className="status-card"><span className="card-label">Dependências ativas</span><strong className="card-value">{kpis.dependenciasAtivas}</strong></div>
        <div className="status-card"><span className="card-label">Tempo médio</span><strong className="card-value">{kpis.tempoMedio}h</strong></div>
        <div className="status-card"><span className="card-label">Horas bloqueadas</span><strong className="card-value">{kpis.horasBloqueadas}h</strong></div>
      </section>
      <section className="panel"><div className="panel-header"><h3>Desempenho por responsável</h3><p>Volume aberto, atrasado e concluído.</p></div><div className="table-wrapper"><table className="operations-table"><thead><tr><th>Pessoa</th><th>Em aberto</th><th>Atrasadas</th><th>Concluídas</th></tr></thead><tbody>{porPessoa.map((p) => <tr key={p.id}><td><strong>{p.nome}</strong></td><td>{p.abertas}</td><td>{p.atrasadas}</td><td>{p.concluidas}</td></tr>)}</tbody></table></div></section>
    </>
  )
}
NEXO_EOF_SRC_PAGES_INDICADORESPAGE_TSX

cat > 'src/App.tsx' <<'NEXO_EOF_SRC_APP_TSX'
import { useEffect, useState } from 'react'
import { supabase } from './lib/supabase'
import Layout from './components/Layout'
import OperacoesPage from './pages/OperacoesPage'
import DemandasPage from './pages/DemandasPage'
import CentralPage from './pages/CentralPage'
import ProcessosGeralPage from './pages/ProcessosGeralPage'
import PessoasGeralPage from './pages/PessoasGeralPage'
import DocumentosPage from './pages/DocumentosPage'
import IndicadoresPage from './pages/IndicadoresPage'
import type { DadosUsuario, Pagina } from './types'
import { buscarUsuarioAtual } from './services/nexoService'
import {
  AdministracaoPage,
  CargosPage,
  EmpresasPage,
  OperacoesCadastroPage,
  PerfisPage,
  PessoasPage,
  ProcessosPage,
  RecorrenciasPage,
  ResponsabilidadesPage,
  SetoresPage,
} from './pages/AdminPages'
import './App.css'

function App() {
  const [email, setEmail] = useState('')
  const [senha, setSenha] = useState('')
  const [mensagem, setMensagem] = useState('')
  const [carregando, setCarregando] = useState(false)
  const [usuario, setUsuario] = useState<DadosUsuario | null>(null)
  const [pagina, setPagina] = useState<Pagina>('central')

  async function carregarUsuario() {
    try {
      const dados = await buscarUsuarioAtual()
      setUsuario(dados)
    } catch (error) {
      console.error(error)
      setMensagem('Erro ao carregar os dados do usuário.')
    }
  }

  useEffect(() => { carregarUsuario() }, [])

  async function entrar(e: React.FormEvent) {
    e.preventDefault()
    setCarregando(true)
    setMensagem('')
    const { error } = await supabase.auth.signInWithPassword({ email, password: senha })
    if (error) setMensagem('E-mail ou senha inválidos.')
    else await carregarUsuario()
    setCarregando(false)
  }

  async function sair() {
    await supabase.auth.signOut()
    setUsuario(null)
    setPagina('central')
    setEmail('')
    setSenha('')
    setMensagem('')
  }

  function renderPagina() {
    if (!usuario) return null
    switch (pagina) {
      case 'central': return <CentralPage usuario={usuario} navegar={setPagina} />
      case 'operacoes': return <OperacoesPage usuario={usuario} />
      case 'demandas': return <DemandasPage usuario={usuario} />
      case 'processos-geral': return <ProcessosGeralPage usuario={usuario} />
      case 'pessoas-geral': return <PessoasGeralPage usuario={usuario} />
      case 'documentos': return <DocumentosPage usuario={usuario} />
      case 'indicadores': return <IndicadoresPage usuario={usuario} />
      case 'administracao': return <AdministracaoPage usuario={usuario} navegar={setPagina} />
      case 'empresas': return <EmpresasPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'setores': return <SetoresPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'cargos': return <CargosPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'pessoas': return <PessoasPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'perfis': return <PerfisPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'processos': return <ProcessosPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'cadastro-operacoes': return <OperacoesCadastroPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'responsabilidades': return <ResponsabilidadesPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'recorrencias': return <RecorrenciasPage usuario={usuario} voltar={() => setPagina('administracao')} />
      default: return <CentralPage usuario={usuario} navegar={setPagina} />
    }
  }

  if (usuario) {
    return <Layout usuario={usuario} pagina={pagina} navegar={setPagina} sair={sair}>{renderPagina()}</Layout>
  }

  return (
    <div className="login-page"><div className="login-card"><div className="logo">NEXO</div><p className="subtitulo">Sistema Operacional da Administração</p><form onSubmit={entrar}><label>E-mail</label><input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required /><label>Senha</label><input type="password" value={senha} onChange={(e) => setSenha(e.target.value)} required /><button type="submit" disabled={carregando}>{carregando ? 'Entrando...' : 'Entrar'}</button>{mensagem && <div className="mensagem">{mensagem}</div>}</form></div></div>
  )
}

export default App
NEXO_EOF_SRC_APP_TSX

cat > 'supabase_nexo_pendencias.sql' <<'NEXO_EOF_SUPABASE_NEXO_PENDENCIAS_SQL'
-- NEXO - consolidação das pendências estruturais
-- Execute no Supabase SQL Editor como postgres.

create or replace function public.usuario_pessoa_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select u.pessoa_id
  from public.usuarios u
  where u.id = auth.uid() and u.ativo = true
  limit 1;
$$;

create or replace function public.usuario_empresa_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select p.empresa_id
  from public.usuarios u
  join public.pessoas p on p.id = u.pessoa_id
  where u.id = auth.uid() and u.ativo = true
  limit 1;
$$;

create or replace function public.usuario_setor_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select p.setor_id
  from public.usuarios u
  join public.pessoas p on p.id = u.pessoa_id
  where u.id = auth.uid() and u.ativo = true
  limit 1;
$$;

create or replace function public.usuario_perfil_nome()
returns text
language sql
security definer
stable
set search_path = public
as $$
  select pf.nome
  from public.usuarios u
  join public.perfis pf on pf.id = u.perfil_id
  where u.id = auth.uid() and u.ativo = true
  limit 1;
$$;

-- Repositório privado
insert into storage.buckets (id, name, public)
values ('nexo-documentos', 'nexo-documentos', false)
on conflict (id) do update set public = false;

-- Acesso ao bucket apenas dentro da empresa do usuário.
drop policy if exists "nexo_documentos_select" on storage.objects;
create policy "nexo_documentos_select"
on storage.objects for select to authenticated
using (
  bucket_id = 'nexo-documentos'
  and (storage.foldername(name))[1] = public.usuario_empresa_id()::text
);

drop policy if exists "nexo_documentos_insert" on storage.objects;
create policy "nexo_documentos_insert"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'nexo-documentos'
  and (storage.foldername(name))[1] = public.usuario_empresa_id()::text
);

drop policy if exists "nexo_documentos_update" on storage.objects;
create policy "nexo_documentos_update"
on storage.objects for update to authenticated
using (
  bucket_id = 'nexo-documentos'
  and (storage.foldername(name))[1] = public.usuario_empresa_id()::text
)
with check (
  bucket_id = 'nexo-documentos'
  and (storage.foldername(name))[1] = public.usuario_empresa_id()::text
);

-- Políticas de leitura por empresa. As policies ADMIN existentes continuam válidas e são combinadas por OR.
do $$
declare t text;
begin
  foreach t in array array['empresas','setores','cargos','pessoas','processos','operacoes','documentos','objetivos','indicadores']
  loop
    execute format('drop policy if exists "nexo_empresa_select_%s" on public.%I', t, t);
  end loop;
end $$;

create policy "nexo_empresa_select_empresas" on public.empresas for select to authenticated using (id = public.usuario_empresa_id());
create policy "nexo_empresa_select_setores" on public.setores for select to authenticated using (empresa_id = public.usuario_empresa_id());
create policy "nexo_empresa_select_cargos" on public.cargos for select to authenticated using (empresa_id = public.usuario_empresa_id());
create policy "nexo_empresa_select_pessoas" on public.pessoas for select to authenticated using (empresa_id = public.usuario_empresa_id());
create policy "nexo_empresa_select_processos" on public.processos for select to authenticated using (empresa_id = public.usuario_empresa_id());
create policy "nexo_empresa_select_operacoes" on public.operacoes for select to authenticated using (empresa_id = public.usuario_empresa_id());
create policy "nexo_empresa_select_documentos" on public.documentos for select to authenticated using (empresa_id = public.usuario_empresa_id());
create policy "nexo_empresa_select_objetivos" on public.objetivos for select to authenticated using (empresa_id = public.usuario_empresa_id());
create policy "nexo_empresa_select_indicadores" on public.indicadores for select to authenticated using (empresa_id = public.usuario_empresa_id());

-- Execuções: leitura por empresa; alteração por responsável/participante ou liderança.
drop policy if exists "nexo_execucoes_select" on public.execucoes;
create policy "nexo_execucoes_select" on public.execucoes for select to authenticated
using (exists (select 1 from public.operacoes o where o.id = operacao_id and o.empresa_id = public.usuario_empresa_id()));

drop policy if exists "nexo_execucoes_update" on public.execucoes;
create policy "nexo_execucoes_update" on public.execucoes for update to authenticated
using (
  responsavel_id = public.usuario_pessoa_id()
  or public.usuario_perfil_nome() in ('ADMIN','LIDER','GESTOR','GERENTE','DIRETORIA')
  or exists (select 1 from public.execucao_participantes ep where ep.execucao_id = id and ep.pessoa_id = public.usuario_pessoa_id() and ep.ativo = true)
)
with check (exists (select 1 from public.operacoes o where o.id = operacao_id and o.empresa_id = public.usuario_empresa_id()));

-- Demandas: empresa inteira pode ler; solicitante/responsável e liderança podem alterar.
drop policy if exists "nexo_demandas_select" on public.demandas;
create policy "nexo_demandas_select" on public.demandas for select to authenticated using (empresa_id = public.usuario_empresa_id());

drop policy if exists "nexo_demandas_insert" on public.demandas;
create policy "nexo_demandas_insert" on public.demandas for insert to authenticated with check (empresa_id = public.usuario_empresa_id() and solicitante_id = public.usuario_pessoa_id());

drop policy if exists "nexo_demandas_update" on public.demandas;
create policy "nexo_demandas_update" on public.demandas for update to authenticated
using (solicitante_id = public.usuario_pessoa_id() or responsavel_id = public.usuario_pessoa_id() or public.usuario_perfil_nome() in ('ADMIN','LIDER','GESTOR','GERENTE','DIRETORIA'))
with check (empresa_id = public.usuario_empresa_id());

-- Documentos: leitura por empresa e criação pelo usuário autenticado.
drop policy if exists "nexo_documentos_insert_table" on public.documentos;
create policy "nexo_documentos_insert_table" on public.documentos for insert to authenticated with check (empresa_id = public.usuario_empresa_id());

-- Procedimentos e vínculos herdados por operação/documento da empresa.
drop policy if exists "nexo_procedimentos_select" on public.procedimentos;
create policy "nexo_procedimentos_select" on public.procedimentos for select to authenticated using (exists (select 1 from public.operacoes o where o.id = operacao_id and o.empresa_id = public.usuario_empresa_id()));

drop policy if exists "nexo_procedimentos_insert" on public.procedimentos;
create policy "nexo_procedimentos_insert" on public.procedimentos for insert to authenticated with check (exists (select 1 from public.operacoes o where o.id = operacao_id and o.empresa_id = public.usuario_empresa_id()));

drop policy if exists "nexo_documento_vinculos_select" on public.documento_vinculos;
create policy "nexo_documento_vinculos_select" on public.documento_vinculos for select to authenticated using (exists (select 1 from public.documentos d where d.id = documento_id and d.empresa_id = public.usuario_empresa_id()));

drop policy if exists "nexo_documento_vinculos_insert" on public.documento_vinculos;
create policy "nexo_documento_vinculos_insert" on public.documento_vinculos for insert to authenticated with check (exists (select 1 from public.documentos d where d.id = documento_id and d.empresa_id = public.usuario_empresa_id()));

-- Segurança contra auto-desativação/auto-rebaixamento acidental do último ADMIN.
create or replace function public.proteger_ultimo_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  perfil_admin uuid;
  qtd_admin integer;
begin
  select id into perfil_admin from public.perfis where nome = 'ADMIN' limit 1;
  if old.perfil_id = perfil_admin and old.ativo = true and (new.perfil_id <> perfil_admin or new.ativo = false) then
    select count(*) into qtd_admin from public.usuarios where perfil_id = perfil_admin and ativo = true and id <> old.id;
    if qtd_admin = 0 then
      raise exception 'Não é permitido remover ou desativar o último usuário ADMIN.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_proteger_ultimo_admin on public.usuarios;
create trigger trg_proteger_ultimo_admin before update on public.usuarios for each row execute function public.proteger_ultimo_admin();

-- Evidências acessíveis pela empresa da execução.
drop policy if exists "nexo_evidencias_select" on public.evidencias;
create policy "nexo_evidencias_select" on public.evidencias for select to authenticated
using (exists (
  select 1 from public.execucoes e
  join public.operacoes o on o.id = e.operacao_id
  where e.id = execucao_id and o.empresa_id = public.usuario_empresa_id()
));

drop policy if exists "nexo_evidencias_insert" on public.evidencias;
create policy "nexo_evidencias_insert" on public.evidencias for insert to authenticated
with check (exists (
  select 1 from public.execucoes e
  join public.operacoes o on o.id = e.operacao_id
  where e.id = execucao_id and o.empresa_id = public.usuario_empresa_id()
));

-- Histórico, conferência, aprovação, bloqueio, dependência e retrabalho:
-- leitura por empresa da execução.
do $$
declare
  t text;
begin
  foreach t in array array['execucao_participantes','execucao_status_historico','dependencias','bloqueios','conferencias','retrabalhos','aprovacoes','carga_trabalho']
  loop
    execute format('drop policy if exists "nexo_fluxo_select_%s" on public.%I', t, t);
  end loop;
end $$;

create policy "nexo_fluxo_select_execucao_participantes" on public.execucao_participantes for select to authenticated using (exists (select 1 from public.execucoes e join public.operacoes o on o.id=e.operacao_id where e.id=execucao_id and o.empresa_id=public.usuario_empresa_id()));
create policy "nexo_fluxo_select_execucao_status_historico" on public.execucao_status_historico for select to authenticated using (exists (select 1 from public.execucoes e join public.operacoes o on o.id=e.operacao_id where e.id=execucao_id and o.empresa_id=public.usuario_empresa_id()));
create policy "nexo_fluxo_select_dependencias" on public.dependencias for select to authenticated using (exists (select 1 from public.execucoes e join public.operacoes o on o.id=e.operacao_id where e.id=execucao_id and o.empresa_id=public.usuario_empresa_id()));
create policy "nexo_fluxo_select_bloqueios" on public.bloqueios for select to authenticated using (exists (select 1 from public.execucoes e join public.operacoes o on o.id=e.operacao_id where e.id=execucao_id and o.empresa_id=public.usuario_empresa_id()));
create policy "nexo_fluxo_select_conferencias" on public.conferencias for select to authenticated using (exists (select 1 from public.execucoes e join public.operacoes o on o.id=e.operacao_id where e.id=execucao_id and o.empresa_id=public.usuario_empresa_id()));
create policy "nexo_fluxo_select_retrabalhos" on public.retrabalhos for select to authenticated using (exists (select 1 from public.execucoes e join public.operacoes o on o.id=e.operacao_id where e.id=execucao_id and o.empresa_id=public.usuario_empresa_id()));
create policy "nexo_fluxo_select_aprovacoes" on public.aprovacoes for select to authenticated using (exists (select 1 from public.execucoes e join public.operacoes o on o.id=e.operacao_id where e.id=execucao_id and o.empresa_id=public.usuario_empresa_id()));
create policy "nexo_fluxo_select_carga_trabalho" on public.carga_trabalho for select to authenticated using (exists (select 1 from public.pessoas p where p.id=pessoa_id and p.empresa_id=public.usuario_empresa_id()));

-- Regras centrais: nenhuma execução pode ser concluída ignorando requisitos.
create or replace function public.validar_conclusao_execucao()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  op record;
begin
  if new.status = 'CONCLUIDA' and old.status is distinct from 'CONCLUIDA' then
    select exige_conferencia, exige_aprovacao, exige_evidencia into op
    from public.operacoes where id = new.operacao_id;

    if exists (select 1 from public.bloqueios b where b.execucao_id = new.id and b.ativo = true) then
      raise exception 'A execução possui bloqueio ativo.';
    end if;

    if exists (select 1 from public.retrabalhos r where r.execucao_id = new.id and r.status in ('PENDENTE','EM_CORRECAO')) then
      raise exception 'A execução possui retrabalho pendente.';
    end if;

    if op.exige_conferencia and not exists (select 1 from public.conferencias c where c.execucao_id = new.id and c.resultado = 'APROVADA') then
      raise exception 'A operação exige conferência aprovada.';
    end if;

    if op.exige_aprovacao and not exists (select 1 from public.aprovacoes a where a.execucao_id = new.id and a.status = 'APROVADA') then
      raise exception 'A operação exige aprovação.';
    end if;

    if op.exige_evidencia and not exists (select 1 from public.evidencias ev where ev.execucao_id = new.id) then
      raise exception 'A operação exige evidência.';
    end if;

    new.percentual_conclusao := 100;
    if new.data_conclusao is null then new.data_conclusao := now(); end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validar_conclusao_execucao on public.execucoes;
create trigger trg_validar_conclusao_execucao before update on public.execucoes for each row execute function public.validar_conclusao_execucao();

-- Sincroniza a demanda vinculada com o andamento da execução.
create or replace function public.sincronizar_demanda_execucao()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.demandas d
  set
    percentual_conclusao = new.percentual_conclusao,
    status = case
      when new.status = 'CONCLUIDA' then 'CONCLUIDA'
      when new.status = 'CANCELADA' then 'CANCELADA'
      when new.status = 'BLOQUEADA' then 'BLOQUEADA'
      when new.status like 'AGUARDANDO_%' then 'AGUARDANDO'
      when new.status in ('NAO_INICIADA') then 'ABERTA'
      else 'EM_EXECUCAO'
    end,
    data_inicio = coalesce(d.data_inicio, new.data_inicio),
    data_conclusao = case when new.status in ('CONCLUIDA','CANCELADA') then coalesce(new.data_conclusao, now()) else d.data_conclusao end,
    updated_at = now()
  where d.execucao_id = new.id;
  return new;
end;
$$;

drop trigger if exists trg_sincronizar_demanda_execucao on public.execucoes;
create trigger trg_sincronizar_demanda_execucao after update on public.execucoes for each row execute function public.sincronizar_demanda_execucao();
NEXO_EOF_SUPABASE_NEXO_PENDENCIAS_SQL

if ! grep -q 'NEXO - CONSOLIDAÇÃO OPERACIONAL' src/App.css; then
cat >> src/App.css <<'NEXO_CSS_EOF'

/* =========================================================
   NEXO - CONSOLIDAÇÃO OPERACIONAL
   ========================================================= */
.nexo-five-cards { grid-template-columns: repeat(5, 1fr); }
.nexo-kpi-grid { grid-template-columns: repeat(4, 1fr); }
.nexo-quick-actions { display:flex; gap:10px; flex-wrap:wrap; margin-bottom:22px; }
.nexo-quick-actions button, .nexo-tabs button { border:1px solid #d1d5db; background:#fff; color:#374151; border-radius:8px; padding:10px 14px; font-weight:600; }
.nexo-quick-actions button:hover, .nexo-tabs button:hover { background:#f3f4f6; }
.nexo-tabs { display:flex; gap:8px; margin-bottom:20px; }
.nexo-tabs button.active { background:#111827; color:#fff; border-color:#111827; }
.nexo-grid-cards { display:grid; grid-template-columns:repeat(3,1fr); gap:14px; padding:20px 22px; }
.nexo-info-card { border:1px solid #e5e7eb; border-radius:10px; padding:16px; background:#fff; }
.nexo-info-card h4 { margin:0 0 12px; }
.nexo-info-card p { margin:6px 0; color:#4b5563; font-size:13px; }
.nexo-muted { margin-top:4px; color:#9ca3af; font-size:12px; }
.nexo-form-panel { margin-bottom:20px; }
.nexo-pad { padding:20px 22px; }
@media (max-width:1100px) { .nexo-five-cards, .nexo-kpi-grid { grid-template-columns:repeat(2,1fr); } .nexo-grid-cards { grid-template-columns:repeat(2,1fr); } }
@media (max-width:700px) { .nexo-five-cards, .nexo-kpi-grid, .nexo-grid-cards { grid-template-columns:1fr; } }
NEXO_CSS_EOF
fi

npm run build
