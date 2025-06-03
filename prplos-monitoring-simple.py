#!/usr/bin/env python3
"""
prplOS Patch Monitoring - Simplified Version
Works without external dependencies like matplotlib
"""

import os
import sys
import json
import time
import subprocess
from datetime import datetime
from collections import defaultdict
import csv

class SimplePatchMonitor:
    """Simplified monitoring without matplotlib/pandas dependencies"""
    
    def __init__(self, results_dir=None):
        self.results_dir = results_dir or os.path.expanduser("~/prplos-workspace/results")
        os.makedirs(self.results_dir, exist_ok=True)
        
        self.data = {
            'timestamps': [],
            'cpu_usage': [],
            'memory_usage': [],
            'patch_times': defaultdict(list),
            'compile_times': defaultdict(list)
        }
    
    def collect_system_metrics(self):
        """Collect current system metrics using basic commands"""
        try:
            # CPU usage
            cpu_cmd = "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1"
            result = subprocess.run(cpu_cmd, shell=True, capture_output=True, text=True)
            cpu_usage = float(result.stdout.strip()) if result.stdout.strip() else 0.0
            
            # Memory usage
            mem_cmd = "free | grep Mem | awk '{print ($3/$2) * 100.0}'"
            result = subprocess.run(mem_cmd, shell=True, capture_output=True, text=True)
            memory_usage = float(result.stdout.strip()) if result.stdout.strip() else 0.0
            
            self.data['timestamps'].append(datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
            self.data['cpu_usage'].append(cpu_usage)
            self.data['memory_usage'].append(memory_usage)
            
            return True
        except Exception as e:
            print(f"Error collecting metrics: {e}")
            return False
    
    def parse_timing_logs(self):
        """Parse timing logs from different patch methods"""
        methods = ['quilt', 'git', 'script']
        
        for method in methods:
            log_file = f"{self.results_dir}/../patch_timing_{method}.log"
            if os.path.exists(log_file):
                try:
                    with open(log_file, 'r') as f:
                        times = [float(line.strip()) for line in f if line.strip()]
                        if times:
                            self.data['patch_times'][method] = times
                except Exception as e:
                    print(f"Error reading {log_file}: {e}")
    
    def display_metrics(self):
        """Display metrics in text format"""
        os.system('clear' if os.name == 'posix' else 'cls')
        
        print("=" * 60)
        print("prplOS Patch Management Monitor - Simplified View")
        print("=" * 60)
        print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("-" * 60)
        
        # System metrics
        if self.data['cpu_usage']:
            print(f"CPU Usage:    Current: {self.data['cpu_usage'][-1]:.1f}%  "
                  f"Avg: {sum(self.data['cpu_usage'])/len(self.data['cpu_usage']):.1f}%")
        
        if self.data['memory_usage']:
            print(f"Memory Usage: Current: {self.data['memory_usage'][-1]:.1f}%  "
                  f"Avg: {sum(self.data['memory_usage'])/len(self.data['memory_usage']):.1f}%")
        
        print("-" * 60)
        
        # Patch timing data
        self.parse_timing_logs()
        if self.data['patch_times']:
            print("Patch Application Performance:")
            for method, times in self.data['patch_times'].items():
                if times:
                    avg_time = sum(times) / len(times)
                    min_time = min(times)
                    max_time = max(times)
                    print(f"  {method:8s}: Avg: {avg_time:.2f}s  "
                          f"Min: {min_time:.2f}s  Max: {max_time:.2f}s  "
                          f"(n={len(times)})")
        
        # Check for benchmark results
        benchmark_file = f"{self.results_dir}/benchmark_summary.csv"
        if os.path.exists(benchmark_file):
            print("-" * 60)
            print("Benchmark Results:")
            try:
                with open(benchmark_file, 'r') as f:
                    reader = csv.DictReader(f)
                    results = list(reader)
                    if results:
                        methods = set(row['method'] for row in results)
                        for method in methods:
                            method_results = [r for r in results if r['method'] == method]
                            print(f"  {method}: {len(method_results)} tests completed")
            except Exception as e:
                print(f"  Error reading benchmark: {e}")
        
        print("=" * 60)
        print("Press Ctrl+C to exit")
    
    def save_report(self):
        """Save a JSON report of collected data"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'system_metrics': {
                'samples': len(self.data['timestamps']),
                'cpu_average': sum(self.data['cpu_usage']) / len(self.data['cpu_usage']) if self.data['cpu_usage'] else 0,
                'memory_average': sum(self.data['memory_usage']) / len(self.data['memory_usage']) if self.data['memory_usage'] else 0
            },
            'patch_performance': {}
        }
        
        for method, times in self.data['patch_times'].items():
            if times:
                report['patch_performance'][method] = {
                    'average': sum(times) / len(times),
                    'min': min(times),
                    'max': max(times),
                    'count': len(times)
                }
        
        report_file = f"{self.results_dir}/monitor_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"\nReport saved to: {report_file}")
        return report_file
    
    def run_interactive(self, update_interval=5):
        """Run interactive monitoring"""
        print("Starting simplified patch monitoring...")
        print("This version works without matplotlib/pandas")
        print("Data directory:", self.results_dir)
        
        try:
            while True:
                self.collect_system_metrics()
                self.display_metrics()
                time.sleep(update_interval)
        except KeyboardInterrupt:
            print("\n\nMonitoring stopped.")
            report_file = self.save_report()
            print(f"Final report: {report_file}")

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Simplified prplOS Patch Monitoring (no external dependencies)'
    )
    parser.add_argument('--results-dir', 
                      default=os.path.expanduser('~/prplos-workspace/results'),
                      help='Directory containing patch results')
    parser.add_argument('--interval', type=int, default=5,
                      help='Update interval in seconds')
    parser.add_argument('--export-only', action='store_true',
                      help='Export report without interactive monitoring')
    
    args = parser.parse_args()
    
    monitor = SimplePatchMonitor(results_dir=args.results_dir)
    
    if args.export_only:
        # Just parse and export
        monitor.parse_timing_logs()
        monitor.collect_system_metrics()
        report_file = monitor.save_report()
        
        # Print report content
        with open(report_file, 'r') as f:
            print(f.read())
    else:
        # Run interactive monitoring
        monitor.run_interactive(update_interval=args.interval)

if __name__ == '__main__':
    main()