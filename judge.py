
import os
import json
import argparse
from pathlib import Path
from mlebench.registry import registry
from mlebench.grade import grade_jsonl

def main():
    print("hello?")
    parser = argparse.ArgumentParser(description="自动评测一个 Run Group 中的所有任务")
    parser.add_argument("run_group_dir", type=str, help="任务组文件夹路径 (例如 runs/2026-01-27...)")
    parser.add_argument("--data-dir", type=str, default=os.path.expanduser("~/.cache/mle-bench/data"), help="数据缓存目录")
    parser.add_argument("--output-dir", type=str, default=None, help="报告输出目录 (默认输出到任务组文件夹内)")
    
    args = parser.parse_args()
    
    run_dir = Path(args.run_group_dir).resolve()
    data_dir = Path(args.data_dir).resolve()
    
    if not args.output_dir:
        output_dir = run_dir
    else:
        output_dir = Path(args.output_dir).resolve()
    
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"📂 扫描任务目录: {run_dir}")
    print(f"💾 数据目录: {data_dir}")

    # 1. 获取所有合法的比赛 ID (用于从文件夹名中反推)
    # 我们需要临时设置数据目录以加载注册表
    local_registry = registry.set_data_dir(data_dir)
    valid_comp_ids = set(local_registry.list_competition_ids())
    
    # 2. 扫描目录寻找 submission.csv
    submissions_list = []
    
    # 遍历 run_group 下的一级子目录 (例如 spaceship-titanic_uuid...)
    for item in run_dir.iterdir():
        if item.is_dir():
            # 尝试匹配比赛 ID
            # 文件夹命名格式通常是: {competition_id}_{uuid}
            # 我们通过“最长前缀匹配”来找到对应的 competition_id
            matched_id = None
            for comp_id in valid_comp_ids:
                if item.name.startswith(comp_id):
                    # 确保匹配的是完整单词 (防止 abc 匹配 abc-def)
                    # 检查剩余部分是否以 _ 开头或者是空字符串（虽然这里一定会有uuid）
                    suffix = item.name[len(comp_id):]
                    if suffix.startswith("_") or suffix == "":
                        # 如果有多个匹配，取最长的那个 (以防 ID 包含下划线)
                        if matched_id is None or len(comp_id) > len(matched_id):
                            matched_id = comp_id
            
            if matched_id:
                # 寻找该目录下的 submission.csv
                # 根据您的 ls -R，它在 subdir/submission/submission.csv
                sub_file = item / "submission" / "submission.csv"
                if sub_file.exists():
                    print(f"✅ 发现提交: {matched_id} -> {sub_file.name}")
                    submissions_list.append({
                        "competition_id": matched_id,
                        "submission_path": str(sub_file)
                    })
                else:
                    print(f"⚠️  跳过 {item.name}: 未找到 submission/submission.csv")
            else:
                print(f"❓ 跳过未知文件夹: {item.name}")

    if not submissions_list:
        print("❌ 未找到任何有效的提交文件。")
        return

    # 3. 生成临时的 input.jsonl 文件
    jsonl_path = output_dir / "grading_input.jsonl"
    with open(jsonl_path, "w") as f:
        for entry in submissions_list:
            f.write(json.dumps(entry) + "\n")
            
    print(f"📝 生成评分清单: {jsonl_path}")
    print("🚀 开始评分 (调用 mlebench 核心逻辑)...")

    # 4. 调用 mlebench 的评分函数
    try:
        # grade_jsonl 会生成最终的报告
        grade_jsonl(jsonl_path, output_dir, local_registry)
        print(f"\n🎉 评分完成！请查看生成在 {output_dir} 下的 json 报告。")
    except Exception as e:
        print(f"\n❌ 评分过程中发生错误: {e}")

if __name__ == "__main__":
    main()