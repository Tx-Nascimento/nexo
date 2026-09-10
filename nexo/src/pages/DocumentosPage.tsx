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

function normalizarRelacao<T>(valor: T | T[] | null | undefined): T | null {
  if (!valor) return null
  return Array.isArray(valor) ? valor[0] || null : valor
}

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
      setDocumentos(
        (d.data || []).map((item: any) => ({
          ...item,
          setor: normalizarRelacao(item.setor),
          pessoa: normalizarRelacao(item.pessoa),
        })) as Documento[]
      )
      setProcedimentos(
        (pr.data || []).map((item: any) => ({
          ...item,
          operacao: normalizarRelacao(item.operacao),
        })) as Procedimento[]
      )
      setSetores((s.data || []) as Setor[])
      setPessoas((pe.data || []) as Pessoa[])
      setProcessos((p.data || []) as Processo[])
      setOperacoes((o.data || []) as Operacao[])
      setExecucoes((ex.data || []) as Execucao[])
      setEvidencias(
        (ev.data || []).map((item: any) => ({
          ...item,
          execucao: normalizarRelacao(item.execucao),
        })) as Evidencia[]
      )
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
